Currently this only illustrates the two pieces of additional behaviour in
`html-derived-writer.lua`.

1.  Convert Para to Plain when:

    * It's the only block, or

    * It's the first of two blocks and the other one is a Div.

    This was originally intended for use in table cells (but actually it
    also affects the above BulletList). Example:

    ::: note

    This would usually be a Para but will be converted to Plain.

    :::

2.  Convert Divs that have attributes (and contain only a BulletList) to a
    BulletList with these attributes

    This is intended to play nicely with the [attributes extension], which will
    insert a Span or Div as needed. Example:

    {#my-list}
    * The above attributes will be associated directly with this BulletList.


[attributes extension]: https://pandoc.org/MANUAL.html#extension-attributes
