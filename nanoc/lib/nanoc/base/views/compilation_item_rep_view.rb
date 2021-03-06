# frozen_string_literal: true

module Nanoc
  class CompilationItemRepView < ::Nanoc::BasicItemRepView
    # @abstract
    def item_view_class
      Nanoc::CompilationItemView
    end

    # Returns the item rep’s raw path. It includes the path to the output
    # directory and the full filename.
    #
    # @param [Symbol] snapshot The snapshot for which the path should be
    #   returned.
    #
    # @return [String] The item rep’s raw path.
    def raw_path(snapshot: :last)
      @context.dependency_tracker.bounce(unwrap.item, compiled_content: true)

      res = @item_rep.raw_path(snapshot: snapshot)

      unless @item_rep.compiled?
        Fiber.yield(Nanoc::Int::Errors::UnmetDependency.new(@item_rep))
      end

      res
    end

    # Returns the compiled content.
    #
    # @param [String] snapshot The name of the snapshot from which to
    #   fetch the compiled content. By default, the returned compiled content
    #   will be the content compiled right before the first layout call (if
    #   any).
    #
    # @return [String] The content at the given snapshot.
    def compiled_content(snapshot: nil)
      @context.dependency_tracker.bounce(unwrap.item, compiled_content: true)
      @context.snapshot_repo.compiled_content(rep: unwrap, snapshot: snapshot)
    end
  end
end
