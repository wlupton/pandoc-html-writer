# pandoc-html-writer

Sample pandoc 3 [custom writers], both of which use the [scaffolding
mechanism].

* `html-writer.lua` is a base writer.

* `html-derived-writer.lua` is a derived writer and illustrates how to modify
  the behaviour of the base writer.

There might be a few missing features in the base writer. Also, I believe that
there's a problem with the handling of table rowspans and colspans; in
addition, please see the XXX comments in the code.

There are also a `sample.md` file and a `makefile`.

[custom writers]: https://pandoc.org/custom-writers.html

[scaffolding mechanism]: https://pandoc.org/custom-writers.html#reducing-boilerplate-with-pandoc.scaffolding.writer
