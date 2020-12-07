module engine.core.resources.iresource;

interface IResource
{
    void resourceName(string name);
    string resourceName();
}

mixin template IResourceBoilerplate()
{
    private string _resourceName;
    void resourceName(string name) { this._resourceName = name; }
    string resourceName() { return this._resourceName; }
}