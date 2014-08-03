require 'rdf'
require 'roadforest/graph/focus-list'
require 'roadforest/graph/graph-focus'

describe RoadForest::Graph::FocusList do
  let :graph do
    RDF::Graph.new
  end

  let :access do
    RoadForest::Graph::WriteManager.new.tap do |access|
      access.source_graph = graph
    end
  end

  let :focus do
    RoadForest::Graph::GraphFocus.new(access, "urn:root")
  end

  let :list do
    focus.as_list
  end

  it "should render correctly empty" do
    focus.add_list(:rdf, :value)

    graph.should match_query { |query|
      query.pattern(:object => RDF.nil)
    }
  end

  it "should raise error if trying to append to an empty list" do
    list = focus.add_list(:rdf, :value)

    expect{ list.append_node("#1") }.to raise_error
  end

  it "should append nodes in an added list" do
    focus.add_list(:rdf, :value) do |list|
      list.append_node("#1")
    end

    graph.should match_query { |query|
      query.pattern(:object => RDF::URI.new("urn:root#1"))
    }
  end

  it "should add an item to graph" do
    list.append_node("#test")

    graph.should match_query { |query|
      query.pattern(:object => RDF::URI.new("urn:root#test"))
    }
  end

  it "should add several items to the graph" do
    list.append_node("#1")
    list.append_node("#2")
    list.append_node("#3")

    focus.as_list.to_a.should have(3).nodes

  end
end
