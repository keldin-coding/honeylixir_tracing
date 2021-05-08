# Changelog

## 0.4.0 (in progress)

## 0.3.0

* Add Reaper for cleaning up ETS table
* Change context to be not a stack and store data solely in the ETS table. The main trade-off here is that the Process dictionary causes garbage collection so if we start storing lots of spans in a Process, it may accumulate more memory than it needs.
* Add utility function for sending link type span annotations
* Add `start_span` and `end_span` for manually managed spans

## 0.2.0

* Add the ability to add fields to the currently active span
* Add tests and CI runs
* Adds `HoneylixirTracing.Propagation` for sending data between processes and to other services as the `"X-Honeycomb-Trace"` header

## 0.1.0

This was a barebones release and should absolutely not be used by people in a real setting. That said, it very basically works for creating spans.
