### How to run the tests

All tests need to be run on a mainnet fork. One test is marked as skipped, since it is highly dependent on the block it is run on (due to exact Uniswap price and reserves in the pool).
When running tests, add `--match-contract Leverager` in order to not run some tests twice.

