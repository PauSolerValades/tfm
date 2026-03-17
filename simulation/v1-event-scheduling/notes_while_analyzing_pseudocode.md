# Notes analyzing the pseudocode

## Post preinitialization

1. Post creation can exceed the warmup timing.
2. Post creation can be when a user is offline -> should never happen

## Receive posts

1. It's `.create`.
2. Can `t_clock +  config.propagation_delay.sample(rng)` happen when the user is offline? At `t_clock` for sure it's not, but at `t_clock + propagation_delay` it might? -> store when user is going offline in an array (or at the user)?




