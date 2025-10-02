# Crappy flex fork
Don't use this fork, here's where I will just fug around and find out. Calling this a fork isn't even proper, it's a disaster. Think of it like you bought a car and decided to rebuild the engine using parts you found at the bottom of a river. That's what this is, don't use it. I shouldn't even use it.


## Thanks & Credits
FLEX builds on ideas and inspiration from open source tools that came before it. The following resources have been particularly helpful:
- [MirrorKit](https://github.com/NSExceptional/MirrorKit): an Objective-C wrapper around the Objective-C runtime.
- [DCIntrospect](https://github.com/domesticcatsoftware/DCIntrospect): view hierarchy debugging for the iOS simulator.
- [PonyDebugger](https://github.com/square/PonyDebugger): network, core data, and view hierarchy debugging using the Chrome Developer Tools interface.
- [Mike Ash](https://www.mikeash.com/pyblog/): well written, informative blog posts on all things obj-c and more. The links below were very useful for this project:
 - [MAObjCRuntime](https://github.com/mikeash/MAObjCRuntime)
 - [Let's Build Key Value Coding](https://www.mikeash.com/pyblog/friday-qa-2013-02-08-lets-build-key-value-coding.html)
 - [ARM64 and You](https://www.mikeash.com/pyblog/friday-qa-2013-09-27-arm64-and-you.html)
- [RHObjectiveBeagle](https://github.com/heardrwt/RHObjectiveBeagle): a tool for scanning the heap for live objects. It should be noted that the source code of RHObjectiveBeagle was not consulted due to licensing concerns.
- [heap_find.cpp](https://www.opensource.apple.com/source/lldb/lldb-179.1/examples/darwin/heap_find/heap/heap_find.cpp): an example of enumerating malloc blocks for finding objects on the heap.
- [Gist](https://gist.github.com/samdmarshall/17f4e66b5e2e579fd396) from [@samdmarshall](https://github.com/samdmarshall): another example of enumerating malloc blocks.
- [Non-pointer isa](http://www.sealiesoftware.com/blog/archive/2013/09/24/objc_explain_Non-pointer_isa.html): an explanation of changes to the isa field on iOS for ARM64 and mention of the useful `objc_debug_isa_class_mask` variable.
- [GZIP](https://github.com/nicklockwood/GZIP): A library for compressing/decompressing data on iOS using libz.
- [FMDB](https://github.com/ccgus/fmdb): This is an Objective-C wrapper around SQLite.
- [InAppViewDebugger](https://github.com/indragiek/InAppViewDebugger): The inspiration and reference implementation for FLEX 4's 3D view explorer, by @indragiek.




## Contributing
Please see our [Contributing Guide](https://github.com/Flipboard/FLEX/blob/master/CONTRIBUTING.md).


## TODO
- Swift runtime introspection (swift classes, swift objects on the heap, etc.)
- Add new NSUserDefault key/value pairs on the fly
