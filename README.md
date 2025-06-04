## `bnet-refunder`

### TODOs

- features?
  - add events to contract
  - claim multiple epochs at once?
    - small gas savings
  - claim multiple accounts at once?
    - no real gas savings
- more test coverage
  - amend previous epoch
  - realistic-sized tree
  - "tree malleability" issues?
  - ???
- offchain part
  - potentially can use `ProofMaker.makeProof()` in a script
- frontend

### Usage

#### Build

```shell
$ forge build
```

#### Test

```shell
$ forge test
```
