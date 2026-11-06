# Slint -- accessibility, view state and e2e tests

Read with `rules.md` (Rust). Applies to every `.slint` file and to the
Rust that feeds its properties and models.

Screen readers AND end-to-end tests see a Slint app only through the
platform accessibility tree (Slint publishes it through AccessKit). A
control with no role, name or state looks fine on screen and is missing
or anonymous in that tree, so the defect ships unnoticed. A view that
is not rewritten after a change looks fine until the user reloads.

Facts below were checked against the Slint 1.x AccessKit mapping and the
AccessKit macOS adapter; re-check the mapping when upgrading Slint.

## 1. Every interactive element is a node with a role and a name

- Only elements whose `accessible-role` is not `none` reach the tree.
  `Rectangle`, `TouchArea` and a custom `component` default to `none`:
  an `accessible-label` set on them alone reaches nothing.
- The name goes on the element that IS the node, and the role on ONE
  element only. A custom text field's node is its inner `TextInput`
  (role `text-input` by default); the wrapper `Rectangle` takes no role.
  A role on the wrapper as well makes two text fields with one name, and
  automation refuses to choose between them. (The std `LineEdit` does
  the reverse -- root `text-input`, inner `TextInput` `none` -- still one
  node.) An icon-only button needs role `button` and a label naming the
  action ("Add row", not "plus").
- A select or field with a caption: `accessible-label` = what it is
  (the caption), `accessible-value` = what it holds now. Never put the
  value into the label. `accessible-placeholder-text` is not a name; a
  placeholder drawn as a `Text` takes `accessible-role: none`.
- A std widget (`ComboBox`, `LineEdit`, `Slider`, ...) takes the name
  at the use site: `ComboBox { accessible-label: @tr("Language"); }`.
- A visible caption `Text` with the same words as the field's label
  makes two nodes with one name (static text + field). Take the caption
  out of the tree with `accessible-role: none`; the field announces it.
- Every interactive element also gets `accessible-action-default` (and
  `accessible-action-expand` for a select), wired to the same code as
  the click, so assistive tech and tests can act without a pointer.

```slint
export component TextField inherits Rectangle {
    in property <string> label;
    in property <string> placeholder;
    in-out property <string> text <=> input.text;
    input := TextInput {
        accessible-label: root.label;
        accessible-placeholder-text: root.placeholder;
    }
    Text { text: root.placeholder; visible: input.text == ""; accessible-role: none; }
}
// caller: one node named "Name", not two
Text { text: @tr("Name"); accessible-role: none; }
TextField { label: @tr("Name"); }
```

## 2. Rows and tabs built from Rectangle + TouchArea expose selection

- A side-bar row that swaps the panel is a `tab` (its container takes
  `accessible-role: tab-list`); a row of a list is a `list-item` (inside
  a `list`); a plain action is a `button`.
- Selection needs BOTH `accessible-item-selectable: true` and
  `accessible-item-selected: <bool>`. Without `selectable` the adapter
  drops `selected` silently. Add `accessible-item-index` / `-count`.

```slint
for s[i] in root.sections: Rectangle {
    accessible-role: tab;
    accessible-label: s.title;
    accessible-item-selectable: true;
    accessible-item-selected: i == root.current;
    accessible-item-index: i;
    accessible-item-count: root.sections.length;
    accessible-action-default => { root.current = i; }
    TouchArea { clicked => { root.current = i; } }
}
```

## 3. Custom toggles expose checkable and checked

- A switch, checkbox, radio or toggle key sets `accessible-role`
  (`switch` / `checkbox` / `radio-button` / `button`),
  `accessible-checkable: true` and `accessible-checked: <bool>`.
  Without `checkable` the adapter drops `checked` silently.
- One control, one checked state: these properties go on the control's
  root only; its track, knob and caption stay `none`.

## 4. What macOS reports (look up and read by THESE)

| Slint | macOS role | State lives in |
|---|---|---|
| `combobox` (std `ComboBox` too) | `AXPopUpButton` -- never `AXComboBox`: Slint has no editable-combobox role | `AXValue` (current choice) |
| `switch`, `checkbox` | `AXCheckBox` | `AXValue` (boolean; tools print `1`/`0` or `true`/`false`), no separate checked attribute |
| `radio-button` | `AXRadioButton` | `AXValue` (boolean) |
| `tab` | `AXRadioButton` (subrole `AXTabButton`) | `AXValue` = selected |
| `list-item` | `AXStaticText` (not a button) | `AXSelected` |
| `text` (`Text`) | `AXStaticText` | `AXValue` holds the text |
| `text-input` (`TextInput`) | `AXTextField` | `AXValue` |
| `button` | `AXButton` (`AXCheckBox` when checkable) | -- |
| `slider` (std `Slider` too) | `AXSlider` | `AXValue` |

- `accessible-label` reaches macOS as `AXTitle`, `accessible-description`
  as `AXHelp`; a `Text` has no title, its text is its `AXValue`.

## 5. A view is written when it opens and after every change to what it shows

- Opening a window for an entity sets EVERY property and model the
  window binds to, from that entity, before `show()`. A property left at
  its default looks like empty data, not like a bug.
- A command that changes the entity on screen (attach, rename, delete,
  reorder) re-publishes it to EVERY view that shows it, not only to the
  view whose callback ran. One place applies the change, re-reads the
  entity from its source of truth, and writes each view's properties and
  models. "It shows after a reload" is the defect.
- The work runs off the UI thread (`rules.md`, Quality). A one-shot
  command result goes back with `upgrade_in_event_loop`; a stream of
  results is polled by the UI timer (`rules.md`).
- The test changes the open entity and asserts the view shows it with
  no reload; it fails before the fix.

```rust
// worker thread, on Cmd::Attach; the loop shows an Err in the view (LAW 18)
fn attach(store: &Store, ui: &slint::Weak<AppWindow>, id: Id, path: &str) -> Result<(), Error> {
    store.attach(id, path)?;
    let rows = attachment_rows(&store.load(id)?); // re-read the source of truth
    ui.upgrade_in_event_loop(move |ui| {
        ui.set_attachments(ModelRc::new(VecModel::from(rows))); // and every other view of it
    })?;
    Ok(())
}
```

## 6. Tests that drive the app through the accessibility tree

- Read state where the platform puts it (rule 4), with the role and
  state mapping in one helper -- never a role literal per test. Plain
  text is found by `AXValue`, not `AXTitle`.
- Before writing a lookup, dump the running app's tree (Accessibility
  Inspector, or the project's AX tool) and use the role it shows.
- One screen-level check -- "every interactive node has a role and a
  non-empty name" -- catches rule 1 for the whole screen at once.
- Off screen is not there. A control outside the visible part of a
  `ScrollView` / `ListView` can be missing from the tree (`ListView`
  creates only the rows on screen) or present and ignoring clicks. Scroll
  the container until the control is inside the visible area, THEN look
  it up and click. Visible = its frame (`AXPosition` + `AXSize`) lies
  inside the container's frame. Never assume a section opens at the
  top -- it can open scrolled to the end: scroll to the top first, then
  down step by step until the control appears.
- A synthetic shortcut can arrive as a letter: a synthetic cmd+A can
  type `a` into a Slint `TextInput`. To clear a field, focus it, press
  the right arrow once per character of its current `AXValue`, then
  backspace the same number of times; check `AXValue` is empty BEFORE
  typing, and check it again after.
- Click order is the test. In "a click is ignored while X is off",
  click the control under test FIRST, before any step (or earlier test
  sharing the app) that turns X on -- otherwise the test passes without
  proving anything.

```text
clear(field): n = len(value(field)); focus(field)
              key(Right) x n; key(Backspace) x n
              assert value(field) == ""          # then type, then assert again
reveal(list, name): scroll_to_top(list)
              until find(list, name) is visible: scroll_down(list, 1 step)
```

## 7. A popup holding a drag control stays open through the drag

- A slider (or any drag) inside a `PopupWindow` must not close it on the
  pointer-down that starts the drag nor on its release. The default
  `close-policy: close-on-click` closes on the release of a click that
  began inside the popup -- the end of every drag. Use
  `close-on-click-outside` (or `no-auto-close` plus an explicit
  `close()`).
- The test drags the slider and asserts the popup is still open AND the
  value changed.

```slint
volume-popup := PopupWindow {
    close-policy: close-on-click-outside; // the default closes when the drag ends
    Slider { value <=> root.volume; }
}
```

## Red flags (first-person; stop and do the rule)

- "The label is on the component, that is enough" -> on a `none`-role
  wrapper it reaches nothing; label the node (rule 1).
- "The caption already says Name" -> the caption is not the field's
  name in the tree, and duplicating it makes two nodes; rule 1.
- "The highlight shows the selected row" -> only on screen; set
  `item-selectable` + `item-selected` (rule 2).
- "A select is a combobox, look it up as AXComboBox" -> macOS reports
  `AXPopUpButton` (rule 4).
- "Read the checked attribute" -> macOS puts on/off in `AXValue`.
- "My list model got the new row" -> and the other views of the same
  entity did not; re-publish to all of them (rule 5).
- "Role on the wrapper AND the inner input, to be safe" -> two fields
  with one name; the role goes on one element (rule 1).
- "It is in that section, so it is in the tree" -> not while scrolled
  away; scroll to it first (rule 6).
- "cmd+A, then type" -> a synthetic shortcut can type the letter; clear
  with arrows + backspace and check `AXValue` (rule 6).
- "Turn X on, then check the click is ignored" -> wrong order; click the
  control under test first (rule 6).
- "The popup's default close policy is fine" -> it closes when the drag
  inside it ends (rule 7).
