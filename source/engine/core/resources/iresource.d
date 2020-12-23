module engine.core.resources.iresource;

interface IResource
{
    void resourceName(string name);
    string resourceName();
}

mixin template IResourceBoilerplate()
{
    private string _resourceName;
    void resourceName(string name) { assert(this._resourceName is null, "I already have a name: "~this._resourceName); this._resourceName = name; }
    string resourceName() { return this._resourceName; }
}