module interfaces.ipackageloader;

import common, interfaces;

interface IPackageLoader
{
    PackageInfo fromFile(string file, PackagecCore core, PackagecCore.GraphT* graph);
}