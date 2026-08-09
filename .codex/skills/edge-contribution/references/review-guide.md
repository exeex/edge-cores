# Pull request review guide

Use the same evidence for maintainer and agent-assisted review.

## Review in order

1. Confirm the PR states one concrete problem and that the diff matches its
   declared scope.
2. Identify affected architectural contracts: instruction encoding, module
   ports, snapshot/sequence ownership, redirect handling, memory visibility,
   ready/valid backpressure, reset, and software ABI.
3. Inspect correctness before style or performance.
4. Check that new behavior has a focused test and that existing regression
   evidence covers shared paths.
5. Reproduce the smallest important test when practical.
6. Verify performance or PPA claims use a stated baseline and comparable
   assumptions.
7. Report actionable findings with file/line location, failure scenario, and
   severity. Do not manufacture findings merely to populate a review.

## Agent review expectations

An internal review agent should read the PR description, base/head diff,
changed tests, and validation evidence. It should independently verify claims
against source and run safe local tests when useful. It must not infer PASS for
untested commands or accept prose as proof of architectural compatibility.

Prioritize:

- silent command loss, duplication, or reordering under backpressure;
- stale snapshot values, sequence wrap, epoch mismatch, and redirect kills;
- ready/valid instability and state advancement without a fired request;
- reset or parameter-depth corner cases;
- encoding or public ABI collisions;
- tests weakened to accommodate a regression; and
- accidental private source, generated output, or secrets in the diff.

Approve only when no actionable correctness issue remains and validation is
proportional to the risk. Missing optional optimization or style preferences
should not block an otherwise correct contribution.
