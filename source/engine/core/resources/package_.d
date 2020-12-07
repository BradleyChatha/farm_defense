module engine.core.resources.package_;

import engine.core.resources;

package final class Package
{
    string name;
    IResource[] resources;
    string[string] aliases;
}