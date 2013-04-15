require 'test_helper'

class StorageNodeTest < MiniTest::Unit::TestCase

	def setup
		create_tree
		@resources = [1, 2, 3]
		@root = @tree_definition.find(:job1).spawn @resources
		@leaf = @tree_definition.find(:job2).spawn @resources, @root
	end

	def test_serialize
		assert_equal '["tree1","job2",1,2,3]', @leaf.send(:serialize)
	end

	def test_storing
		@leaf.store
		assert_parent_key(
      'ResqueJobsTree:Node:["tree1","job2",1,2,3]' => 'ResqueJobsTree:Node:["tree1","job1",1,2,3]')
		assert_equal ['ResqueJobsTree:Node:["tree1","job2",1,2,3]'], redis.smembers(@root.childs_key)
		@leaf.unstore
		assert_parent_key({})
		assert_equal [], redis.smembers(@root.childs_key)
	end

	def test_cleanup_for_root
		create_3_nodes
		@spawn1.cleanup
		assert_equal [], redis.keys
	end

	def test_cleanup_for_leaf
		create_3_nodes
		@spawn3.cleanup
		assert_equal [ 'ResqueJobsTree:Tree:Launched',
                   'ResqueJobsTree:Node:Parents',
                   'ResqueJobsTree:Node:["tree1","job1",1]:childs',
                   'ResqueJobsTree:Node:["tree1","job2"]:childs'], redis.keys
		assert_parent_key( 'ResqueJobsTree:Node:["tree1","job2"]' => 'ResqueJobsTree:Node:["tree1","job1",1]',
                       'ResqueJobsTree:Node:["tree1","job3",2]' => 'ResqueJobsTree:Node:["tree1","job2"]')
		assert_trees_key ['ResqueJobsTree:Tree:["tree1",1]']
	end

	def test_cleanup_for_not_root_nor_leaf
		create_3_nodes
		@spawn2.cleanup
		assert_equal [ 'ResqueJobsTree:Tree:Launched',
                   'ResqueJobsTree:Node:["tree1","job1",1]:childs'], redis.keys
		assert_parent_key({})
		assert_trees_key ['ResqueJobsTree:Tree:["tree1",1]']
	end

	def test_parent
		@leaf.store
		@leaf.instance_variable_set :@parent, nil
		assert_equal @root.name, @leaf.parent.name
		assert_equal @root.resources, @leaf.parent.resources
	end

	def test_only_stored_child
		assert @leaf.only_stored_child?
		@leaf.store
		assert @leaf.only_stored_child?
		resources2 = [4,5,6]
		leaf2 = @tree_definition.find(:job2).spawn resources2, @root
    leaf2.store
		assert !@leaf.only_stored_child?
	end

	def test_stored_childs
		@leaf.store
		resources2 = [4,5,6]
		leaf2 = @tree_definition.find(:job2).spawn resources2, @root
    leaf2.store
		assert_equal %w(job2 job2), @root.stored_childs.map(&:name)
		assert_equal [[4,5,6],[1,2,3]], @root.stored_childs.map(&:resources)
	end

	def test_node_info_from_key
		key = %Q{ResqueJobsTree:Node:["tree1","job1",1,2,3]}
		result = ['job1', [1, 2, 3]]
		assert_equal result, @root.send(:node_info_from_key, key)
	end

	private

	def assert_parent_key expected
		assert_equal expected, redis.hgetall(ResqueJobsTree::Storage::PARENTS_KEY)
	end

	def assert_trees_key expected
		assert_equal expected, redis.smembers(ResqueJobsTree::Storage::LAUNCHED_TREES)
	end

	def create_3_nodes
		@tree_definition = ResqueJobsTree::Factory.create :tree1 do
			root :job1 do
				perform {}
				childs { [[:job2]] }
				node :job2 do
					perform {}
					childs { [[:job3, 1],[:job3, 2]] }
					node :job3 do
						perform {|n|}
					end
				end
			end
		end
		@tree = @tree_definition.spawn [1]
		@spawn1 = @tree_definition.root.spawn [1]
		@spawn2 = @tree_definition.find(:job2).spawn [], @spawn1
		@spawn3 = @tree_definition.find(:job3).spawn [1], @spawn2
		@spawn4 = @tree_definition.find(:job3).spawn [2], @spawn2
		[@tree, @spawn2, @spawn3, @spawn4].each &:store
	end

end
