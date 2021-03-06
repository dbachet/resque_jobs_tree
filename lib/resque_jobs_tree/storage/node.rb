module ResqueJobsTree::Storage::Node
	include ResqueJobsTree::Storage

  def store
    raise 'Can\'t store a root node' if root?
		redis.hset PARENTS_KEY, key, parent.key
		unless redis.sadd parent.childs_key, key
			raise ResqueJobsTree::JobNotUniq,
				"Job #{parent.name} already has the child #{name} with resources: #{resources}"
		end
  end

  def unstore
		redis.srem parent.childs_key, key
		redis.hdel PARENTS_KEY, key
  end

  def cleanup
		unless definition.leaf?
			stored_childs.each &:cleanup
			redis.del childs_key
		end
    redis.hdel PARENTS_KEY, key
    tree.unstore if root?
  end

  def childs_key
    "#{key}:childs"
  end

  def key
    "ResqueJobsTree:Node:#{serialize}"
  end

  def only_stored_child?
    (redis.smembers(parent.childs_key) - [key]).empty?
  end

  def stored_childs
    redis.smembers(childs_key).map do |_key|
      node_name, _resources = node_info_from_key _key
      definition.find(node_name).spawn _resources
    end
  end

  def parent
    @parent ||= definition.parent.spawn node_info_from_key(parent_key).last
  end
  
  def lock_key
    "#{key}:lock"
  end

  def exists?
    if definition.root?
      tree.exists?
    else
      redis.exists(childs_key) || redis.hexists(PARENTS_KEY, key)
    end
  end

	private

  def lock
    _key = parent.lock_key
    while !redis.setnx(_key, 'locked')
      sleep 0.05 # 50 ms
    end
    yield
  ensure
    redis.del _key
  end

  def parent_key
    redis.hget PARENTS_KEY, key
  end

  def node_info_from_key _key
    tree_name, node_name, *resources_arguments = JSON.load(_key.gsub /ResqueJobsTree:Node:/, '')
    _resources = ResqueJobsTree::ResourcesSerializer.instancize(resources_arguments)
		[node_name, _resources]
  end

	def main_arguments
		[definition.tree.name, name]
	end
  
end
