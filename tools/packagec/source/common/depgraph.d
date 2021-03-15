module common.depgraph;

import std.typecons : Nullable;

const DEPENDENCY_ROOT_NODE_NAME = "__root";

struct DependencyNode(ValueT)
{
    private typeof(this)*[] _dependants;
    private bool _hasBeenGivenDependency; // Root also counts. This is just to detect "orphaned" nodes.
    private string _name;
    private bool _topSortMarked;
    Nullable!ValueT value;

    this(string name)
    {
        this._name = name;
    }

    string name() const
    {
        return this._name;
    }

    typeof(this)*[] dependants()
    {
        return this._dependants;
    }

    bool hasBeenGivenDependency() const
    {
        return this._hasBeenGivenDependency;
    }
}

// My "interesting" implementation of an unweighted DAG.
//
// Nodes point towards their dependants rather than dependencies.
// Nodes with no dependencies are attached onto a root node.
// Nodes with no dependencies that are not attached to the root node are likely non-existant (referenced by another node, but no code defines it to be dependency-less).
// Nodes that exist but don't have a value are also non-existant (referenced by another node, but it never gets defined).
struct DependencyGraph(ValueT)
{
    import core.stdcpp.vector;

    @disable this(this) {}

    alias NodeT = DependencyNode!ValueT;

    private
    {
        NodeT*[string] _nodesByName;
    }

    NodeT* addOrGetByName(string nodeName)
    {
        return this._nodesByName.require(nodeName, new NodeT(nodeName));
    }

    NodeT*[2] addDependency(string dependantName, string dependencyName)
    {
        import std.algorithm : canFind;

        auto dependency = this.addOrGetByName(dependencyName);
        auto dependant = this.addOrGetByName(dependantName);

        if(!dependency.dependants.canFind(dependant))
        {
            dependant._hasBeenGivenDependency = true;
            dependency._dependants ~= dependant;
        }

        return [dependant, dependency];
    }

    void enforceGraphIsValid()
    {
        import std.algorithm : filter, map, joiner, reduce;
        import std.format    : format;
        import std.exception : enforce, assumeUnique;

        char[] output;

        // Do simpler checks first.
        auto result = this._nodesByName
                          .byValue
                          .map!((node) 
                          {
                              return (!node.hasBeenGivenDependency && node.name != DEPENDENCY_ROOT_NODE_NAME)
                                     ? "Node %s has no dependencies (not even root). This is likely a sign of a non-existent dependency being referenced.".format(node.name)
                                     : (node.value.isNull && node.name != DEPENDENCY_ROOT_NODE_NAME)
                                       ? "Node %s does not have a value. This is likely a sign of a non-existent dependency being referenced.".format(node.name)
                                       : null;
                          })
                          .filter!(str => str !is null);
        foreach(str; result.joiner("\n"))
            output ~= str;

        // Then do a cycle check.
        // The CPP vector implementation is more efficient to use as a stack than the built-in D arrays when used in an "obvious" manner.
        auto stack = vector!(NodeT*)(DefaultConstruct.init);
        this.enforceNoCycles(this.addOrGetByName(DEPENDENCY_ROOT_NODE_NAME), output, stack);

        enforce(output is null, output.assumeUnique);
    }

    string toString()
    {
        // graphviz dot .gv format
        // online visualiser here: https://dreampuf.github.io/GraphvizOnline
        import std.array     : Appender;
        import std.exception : assumeUnique;

        Appender!(char[]) output;

        output.put("digraph G {\n");
        foreach(node; this._nodesByName.byValue)
        {
            output.put("\t\"");
            output.put(node.name);
            output.put('"');
            output.put('\n');
            foreach(dependant; node.dependants)
            {
                output.put("\t\"");
                output.put(node.name);
                output.put('"');
                output.put(" -> \"");
                output.put(dependant.name);
                output.put('"');
                output.put('\n');
            }
        }
        output.put('}');
        return output.data.assumeUnique;
    }

    NodeT*[] topSort()
    {
        foreach(node; this._nodesByName.byValue)
            node._topSortMarked = false;

        auto toReturn = new NodeT*[this._nodesByName.length - 1]; // - 1 since we're not adding the root in.
        size_t cursor = toReturn.length - 1;

        void visit(bool add)(NodeT* node)
        {
            if(node._topSortMarked)
                return;

            node._topSortMarked = true;

            foreach(child; node.dependants)
                visit!true(child);

            static if(add)
                toReturn[cursor--] = node;
        }

        visit!false(this.addOrGetByName(DEPENDENCY_ROOT_NODE_NAME));

        return toReturn;
    }

    private void enforceNoCycles(NodeT* node, ref char[] output, ref vector!(NodeT*) stack)
    {
        import std.algorithm : map;
        import std.format : format;

        // There's always potential here for a stack overflow (I don't think this can be tail-called), but if the dataset
        // ever becomes large enough to make that happen, then I'll change this code when the time comes.
        if(node.dependants is null)
            return;

        foreach(dep; node._dependants)
        {
            foreach(stackNode; stack)
            {
                if(stackNode is dep)
                {
                    if(output.length == 0 || output[$-1] != '\n')
                        output ~= '\n';

                    output ~= "Cycle detected for node %s: %s".format(dep.name, (stack[0..$] ~ dep).map!(ptr => ptr.name));
                    return;
                }
            }

            stack.push_back(dep);
            this.enforceNoCycles(dep, output, stack);
            stack.pop_back();
        }
    }
}

@("DependencyGraph - Basic valid usage")
unittest
{
    auto graph = new DependencyGraph!int;
    auto nodes = graph.addDependency("A", "B");
    nodes[0].value = 0;
    nodes[1].value = 1;

    nodes = graph.addDependency("B", "C");
    nodes[1].value = 2;
    
    graph.addDependency("C", DEPENDENCY_ROOT_NODE_NAME);
    graph.enforceGraphIsValid();
}

@("DependencyGraph - Orphaned nodes")
unittest
{
    import std.exception : assertThrown;

    auto graph = new DependencyGraph!int;
    graph.addOrGetByName("NA").value = 0;
    graph.enforceGraphIsValid().assertThrown;
}

@("DependencyGraph - Nodes with no value")
unittest
{
    import std.exception : assertThrown;

    auto graph = new DependencyGraph!int;
    graph.addDependency("A", DEPENDENCY_ROOT_NODE_NAME);
    graph.enforceGraphIsValid().assertThrown;
}

@("DependencyGraph - Cycles")
unittest
{
    import std.exception : assertThrown;

    auto graph = new DependencyGraph!int;
    auto nodes = graph.addDependency("A", DEPENDENCY_ROOT_NODE_NAME);
    nodes[0].value = 0;

    nodes = graph.addDependency("A", "B");
    nodes[1].value = 0;

    graph.addDependency("B", "A");
    graph.enforceGraphIsValid().assertThrown;
}

@("DependencyGraph - Top sort")
unittest
{
    import std.algorithm : equal, map;
    import std.conv : to;

    auto graph = new DependencyGraph!int;
    auto nodes = graph.addDependency("2.png", DEPENDENCY_ROOT_NODE_NAME);
    nodes[0].value = 0;

    nodes = graph.addDependency("1.png", DEPENDENCY_ROOT_NODE_NAME);
    nodes[0].value = 0;

    nodes = graph.addDependency("test_image_2", "2.png");
    nodes[0].value = 0;

    nodes = graph.addDependency("test", "test_image_2");
    nodes[0].value = 0;
    graph.addDependency("test", "1.png");
    graph.enforceGraphIsValid();

    auto sorted = graph.topSort();
    assert(sorted.map!(n => n.name).equal(["1.png", "2.png", "test_image_2", "test"]), sorted.map!(n => n.name).to!string);
}