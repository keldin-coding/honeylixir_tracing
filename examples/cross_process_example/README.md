# CrossProcessExample

This is an example application. You can use this to test out the cross-process propagation functionality by starting a mix console:

```bash
$ iex -S mix
```

`CrossProcessExample.put_value/2` will put a value in a single span, synchronously.
`CrossProcessExample.get_value/1` will read the value as two spans: 1 from the caller module and one inside the GenServer. You can verify the propagation worked by ensuring the span is a child but with a different `pid` as logged.
