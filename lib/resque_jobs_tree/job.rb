class ResqueJobsTree::Job

  class << self

    def perform *args
      node(*args).perform
    end

    protected

    def before_perform_run_callback *args
      node(*args).before_perform
    end

    def after_perform_run_callback *args
      node(*args).after_perform
    end

    def on_failure_run_callback exception, *args
      node(*args).on_failure
    end

    def node tree_name, job_name, *resources_arguments
      node_definition = ResqueJobsTree.find(tree_name).find job_name
      resources       = ResqueJobsTree::ResourcesSerializer.instancize resources_arguments
      node = node_definition.spawn(resources)
      if node.exists?
        node
      else
        puts "Warning, the job #{node.definition.tree.name}##{node.definition.name}##{node.resources.inspect} " \
             "doesn't exist. Cleaning-up."
        node.cleanup
        FakeNode.new
      end
    end

  end

  class FakeNode
    def method_missing *args
      # do nothing
    end
  end

end
