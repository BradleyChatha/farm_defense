## Export settings

`Edit > Preferences > Export Options`

**TICK**:

* Embed Tilesets

* Detach templates

* Resolve object types and properties

This will embed all pieces of information directly into the map file itself. While it does waste memory space by having the game reprocess things it technically
shouldn't need to, it simplifies the loading code a *lot*.

## Other notes

Export files should never be embedded inside a folder other than EXPORT (and no deeper than EXPORT), otherwise the poorly written map compile code
for compile_resources.d will fail to produce the correct path to any texture files.