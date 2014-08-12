# Roadforest
### Wherein the author attempts to explain himself

_"Persons attempting to find a motive in this narrative will be prosecuted;
persons attempting to find a moral in it will be banished; persons attempting
to find a plot in it will be shot."_ -- Mark Twain

Roadforest is an experiment in implementing a web framework. The chief
hypothesis being: if many of the decisions related to implementing a RESTful
web application were simply made unilaterally, can we get the benefits of REST
without the bikeshedding and hand wringing of designing it.

## Preface

In the course of designing Roadforest to I've been hewing pretty closely to
"proper" Fielding-thesis Hypermedia style REST. I've tried to incorporate
current thinking as I understand it, including e.g.
[HFactor]:http://amundsen.com/hypermedia/hfactor/ .

That said, this is a field where the state of the art is in flux, and
terminology has been used in different contexts in ways that are mutually
incompatible ways. As a result, there's a lot of jargon I'm uncomfortable with
using here, up to and including "REST" except perhaps followed by the phrase
"architectural style."

For instance, maybe Roadforest supports the Semantic Web, or Linked Data, or
Hypermedia APIs. I have no position on whether this is so.

## Introduction

In broad strokes, Roadforest transmits RDF over HTTP. Clients and servers work
with abstract RDF graph fragments. Servers partition the representation of the
graph into resources identified by URLs. Clients start from the well known URL
of the overall application and walk the graph to discover and modify the state
of the application.

### RDF

Seeing as how <abbr title="Resource Description Framework">RDF</abbr> is
somewhat mysterious and often badly explained, let's digress for a moment and
talk about that.

#### Graphs
##### (The other kind)

Picture an interconnected network of things. The things are connected to each
other by lines or arrows. Everything, both things and arrows, has a name to
describe and reference it.

As a programmer, you do this all the time. For instance, when you write a JSON
document, you're drawing a little network, shaped like a tree, where the things
are objects, e.g. `{ "name": "A Thing or 'Node'" }` that are connected to each
other and to simple values with their properties.

That network, we call a _graph_. The things in the graph are called _nodes_ and
the arrows connecting them are called _edges_. Congratulations, you now know
everything you need to know about Graph Theory.

As previously alluded to, trees are a kind of graph with special rules about
how the edges point - roughly speaking, all the edges point down the tree. If
you've ever had to stop and think about how to work around having the same
chunk of data in two places in a JSON document, you can see how not having to
live by that rule could be handy.

#### Enter RDF

RDF represents graphs as a list of "statements" - a subject, predicate, object
triple that describes an edge in a graph. The 'predicate' is the name of the
edge. The nodes of a graph are all the subjects and objects of statements.

They're called that because, intuitively, a statement in an RDF graph says
"<subject> is related by <predicate> to <object>."

Let's have a concrete example:

`http://lrdesign.com/people/judson foaf:knows http://lrdesign.com/people/evan
.`

means something like "Judson knows Evan."

I should mention: all the names in RDF are URIs. Also there's a trick called
"curies" that lets you simplify repeating URLs by replacing a common prefix
with a shorthand joined with a `:`. So `foaf:knows` means the same as
`http://xmlns.com/foaf/spec/#term_knows`.

### The Point

The point is that RDF lets you describe a general graph of nodes and their
relationships to each other, and that the nodes (and their relationships) are
named with URIs. And hey, we're web programmers, so actually putting things on
a web server to that those node URIs are actually URLs is natural and easy to
do. (A URI (I for Identifier) doesn't have the guarantee that there's anything
on the other end - it's just a name, where a URL (L for Locator) does imply
that you could open it in a browser and find something there.)

### Media Types

RDF itself really is just rules about lists of statements. But to use it, we
need to write it down somehow and send it over the wire. Fortunately, there are
scads of ways to do this. Many of them involve embedding the format in other
media. For instance,
[JSON-LD]: http://json-ld.org/
is an embedding of RDF in JSON. There's also a very readable textual format
called
[Turtle]: http://www.w3.org/TR/turtle/ .

(to be continued...)
