# Quality -- the ISO/IEC 25010 model, CWE as the defect list

A group of `../rules.md` (the index -- read it first). LAW numbers are
global; the language leaves cite them. Each rule binds with no
time-pressure, authority, or sunk-cost exception.

The other groups say HOW to work. This one says WHAT the result must be,
using two public references instead of rules invented one incident at a
time:

- **ISO/IEC 25010:2023** -- the product quality model: nine
  characteristics, each split into subcharacteristics. It is the
  skeleton: nothing a user can suffer falls outside it.
- **CWE** (MITRE, cwe.mitre.org) -- the catalog of software defect
  classes. Its CISQ view (CWE-1305, the measures of ISO/IEC 5055) maps
  CWE entries onto four of these characteristics; the others take
  entries from the rest of the catalog. An ID below is a pointer: recall
  the whole entry -- its description, examples, and mitigations -- not
  only its title.

## LAWs

40. **Every change meets the nine quality characteristics, and is checked
    against them twice.** BEFORE writing, write one line per
    characteristic below: the concrete target the change must hold (a
    number, a limit, a contract) or the observable reason it does not
    apply. AFTER writing, read the diff against each characteristic's CWE
    entries; each is ruled out by a test or by pointing at the line that
    prevents it, never by assumption. Existing code is held to the same
    list: a helper, pattern, or neighbour the change reuses is checked
    BEFORE reuse, and a defect found there is fixed or bypassed with a
    correct variant -- never extended to the new feature. A change that
    touches only docs, comments, or formatting is exempt.

## The checklist

For each characteristic: the question the change must answer, then the
CWE entries that are its concrete failures.

1. **Functional suitability** (completeness, correctness,
   appropriateness) -- Does it do all of what was asked, with the right
   result on every edge: empty, one, maximum, boundary, unit, rounding,
   time zone, encoding? A partial feature is not reported as done.
   CWE-682, CWE-681, CWE-197, CWE-190, CWE-369, CWE-1077, CWE-697,
   CWE-480, CWE-783, CWE-835. Also LAWs 1, 11, 13.
2. **Performance efficiency**
   - *Time behaviour* -- The latency the caller needs, stated and met;
     nothing on a latency-critical or real-time path waits on I/O, a
     lock, or an allocation; no work that grows faster than the input
     where linear will do. CWE-407, CWE-1067, CWE-1050, CWE-1046,
     CWE-1088.
   - *Resource utilization* -- Memory, CPU, handles, connections and
     threads grow with the unit of work, never with the size of the
     input. Input whose size the code does not control -- a file, media,
     an upload, a download, a query result, a message stream -- is
     processed a bounded piece at a time (streamed, paged, memory-mapped)
     by EVERY reader of it: the main path and also previews, waveforms,
     thumbnails, hashes, analysis, export. A derived copy (resampled,
     transcoded, decompressed) is written once to storage and read from
     there the same way. Every acquired resource is released on every
     path. CWE-400, CWE-770, CWE-789, CWE-1325, CWE-1043, CWE-401,
     CWE-404, CWE-459, CWE-772, CWE-775, CWE-1072, CWE-1049, CWE-1060,
     CWE-1073, CWE-1094.
   - *Capacity* -- The largest realistic input and the concurrency are
     written as numbers, and peak memory and latency are measured with
     them before delivery (LAW 3). A cost that grows with the input is a
     CWE-770 finding, not a trade-off to report.
3. **Compatibility** (co-existence, interoperability) -- It shares the
   machine, process, bus, files, ports and devices without starving or
   corrupting its neighbours, and it speaks the exact contract of every
   system it talks to: format, version, encoding, units; old clients,
   stored data and config keep working. CWE-435, CWE-436, CWE-662,
   CWE-1047. Also LAWs 9, 28.
4. **Interaction capability** (recognizability, learnability,
   operability, user error protection, engagement, inclusivity, user
   assistance, self-descriptiveness) -- Any surface a person or another
   program operates (screen, CLI, API, message, log) says what it does,
   rejects bad input early with a specific message, protects against
   irreversible mistakes, and is accessible. CWE-20, CWE-1286,
   CWE-1287, CWE-754, CWE-209. Screens: the `ux-ui` skill. Also LAW 4.
5. **Reliability** (faultlessness, availability, fault tolerance,
   recoverability) -- Every error path is handled and reported, shared
   state is synchronized, every remote call has a timeout, and after a
   crash or restart it recovers with no manual cleanup and no
   half-written state. CWE-252, CWE-390, CWE-391, CWE-392, CWE-703,
   CWE-248, CWE-476, CWE-665, CWE-908, CWE-457, CWE-672, CWE-416,
   CWE-362, CWE-366, CWE-567, CWE-667, CWE-820, CWE-821, CWE-833,
   CWE-1088, CWE-835, CWE-758. Also LAWs 4, 7, 12, 18, 27.
6. **Security** (confidentiality, integrity, non-repudiation,
   accountability, authenticity, resistance) -- Input is neutralized at
   every interpreter boundary, every object access is authorized, no
   secret is hard-coded or rendered, and who did what is recorded. The
   CWE Top 25 of the current year is the floor. CWE-20, CWE-22, CWE-77,
   CWE-78, CWE-79, CWE-89, CWE-94, CWE-434, CWE-502, CWE-611, CWE-918,
   CWE-862, CWE-863, CWE-639, CWE-287, CWE-306, CWE-352, CWE-732,
   CWE-798, CWE-532, CWE-327, CWE-778. Also LAW 6.
7. **Maintainability** (modularity, reusability, analysability,
   modifiability, testability) -- Small units with one reason to change,
   no cycles, no dead or duplicated code, no unexplained literal, and
   testable without infrastructure. CWE-561, CWE-1041, CWE-1047,
   CWE-1048, CWE-1052, CWE-1064, CWE-1080, CWE-1085, CWE-478, CWE-570,
   CWE-571, CWE-1095, CWE-1120, CWE-1121. Also the `design.md` group and
   LAWs 24, 38.
8. **Flexibility** (adaptability, scalability, installability,
   replaceability) -- It runs on every platform the product claims, with
   no hard-coded path, host, or OS assumption; it scales with load
   (stateless) and with input size (item 2); it installs and uninstalls
   with one documented command; each dependency can be swapped behind
   its contract. CWE-1051, CWE-1052, CWE-1104, CWE-426. Also LAWs 8,
   21, 22, 25, 26.
9. **Safety** (operational constraint, risk identification, fail safe,
   hazard warning, safe integration) -- When it drives something real or
   irreversible -- hardware, levels, money, deletion, another person's
   data -- it stays inside the limits, fails to a safe state, warns
   before the hazard, and puts back any state it borrowed on every exit
   path, errors and interruptions included. CWE-636, CWE-460, CWE-459,
   CWE-754, CWE-1188.

## Rationalizations -- and the reality

Populated from real subagent output (RED phase). If you catch yourself
forming one of these, you are about to violate the LAW. Stop.

| Excuse (verbatim pattern) | Reality |
|---|---|
| "Reuse what exists / follow the existing pattern -- it works fine in production" | "Works in production" proves the old input fit; it says nothing about the new one. The reused helper is checked against this list BEFORE reuse (LAW 40); a defect found there is not a pattern. |
| "That is about 700 MB of RAM" -- stated, then kept | Naming a cost that grows with the input and keeping it is the violation (CWE-770), not a disclosed trade-off. Bound it. |
| "I want to try it tonight / keep it simple" | The bounded version is the same size of code -- a stream is one loop. A deadline does not remove a characteristic. |
| "CWE is a security list, this is not a security change" | CWE covers reliability, efficiency and maintainability too -- that is what the CISQ view (ISO/IEC 5055) is. |
| "Not applicable" with no reason | Every characteristic gets a target or an observable reason. "N/a" without one is a skipped check. |

## Red Flags -- STOP

- "Read it all into memory, it is simpler" -> item 2 (CWE-400, CWE-770).
- "Same pattern as the existing code" without checking that code -> LAW 40.
- "It costs N MB / N seconds, acceptable" -> item 2, capacity: bound it.
- "Performance is a later optimization" -> item 2 is a characteristic,
  not an optimization.
- "No timeout needed, that service is fast" -> item 5 (CWE-1088).
- "I'll restore the device / mode / flag later" -> item 9 (CWE-460).
