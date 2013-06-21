# encoding: utf-8

class Nanoc::CompilerTest < Nanoc::TestCase

  def new_snapshot_store
    Nanoc::SnapshotStore::InMemory.new
  end

  def test_compile_with_no_reps
    with_site do
      site = Nanoc::SiteLoader.new.load
      site.compile

      assert Dir['output/*'].empty?
    end
  end

  def test_compile_with_one_rep
    with_site do
      File.write('content/index.html', 'o hello')

      site = Nanoc::SiteLoader.new.load
      site.compile

      assert_equal [ 'output/index.html' ], Dir['output/*']
      assert File.file?('output/index.html')
      assert File.read('output/index.html') == 'o hello'
    end
  end

  def test_compile_with_two_independent_reps
    with_site do
      File.write('content/foo.html', 'o hai')
      File.write('content/bar.html', 'o bai')

      site = Nanoc::SiteLoader.new.load
      site.compile

      assert Dir['output/*'].size == 2
      assert File.file?('output/foo/index.html')
      assert File.file?('output/bar/index.html')
      assert File.read('output/foo/index.html') == 'o hai'
      assert File.read('output/bar/index.html') == 'o bai'
    end
  end

  def test_compile_with_two_dependent_reps
    with_site(:compilation_rule_content => 'filter :erb') do
      File.write(
        'content/foo.html',
        '<%= @items["/bar.html"].compiled_content %>!!!')
      File.write(
        'content/bar.html',
        'manatee')

      site = Nanoc::SiteLoader.new.load
      site.compile

      assert Dir['output/*'].size == 2
      assert File.file?('output/foo/index.html')
      assert File.file?('output/bar/index.html')
      assert File.read('output/foo/index.html') == 'manatee!!!'
      assert File.read('output/bar/index.html') == 'manatee'
    end
  end

  def test_compile_with_two_mutually_dependent_reps
    with_site(:compilation_rule_content => 'filter :erb') do
      File.write(
        'content/foo.html',
        '<%= @items.find { |i| i.identifier == "/bar.html" }.compiled_content %>')
      File.write(
        'content/bar.html',
        '<%= @items.find { |i| i.identifier == "/foo.html" }.compiled_content %>')

      site = Nanoc::SiteLoader.new.load
      assert_raises Nanoc::Errors::RecursiveCompilation do
        site.compile
      end
    end
  end

  def test_load_should_be_idempotent
    with_site do |site|
      compiler = Nanoc::Compiler.new(site)
      def compiler.load_rules
        raise 'oh my gosh it is borken'
      end

      assert site.instance_eval { !@loaded }
      assert_raises(RuntimeError) { compiler.load }
      assert site.instance_eval { !@loaded }
      assert_raises(RuntimeError) { compiler.load }
    end
  end

  def test_compile_should_recompile_all_reps
    with_site do
      File.write('content/foo.md', 'blah')

      site = Nanoc::SiteLoader.new.load
      site.compile

      site = Nanoc::SiteLoader.new.load
      site.compile

      # At this point, even the already compiled items in the previous pass
      # should have their compiled content assigned, so this should work:
      site.compiler.item_rep_store.reps.each { |r| r.compiled_content }
    end
  end

  def test_disallow_multiple_snapshots_with_the_same_name
    with_site do
      # Create file
      File.write('content/stuff', 'blah')

      # Create rules
      File.open('Rules', 'w') do |io|
        io.write "compile '/**/*' do\n"
        io.write "  snapshot :aaa\n"
        io.write "  snapshot :aaa\n"
        io.write "  write '/index.html'\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      # Compile
      site = Nanoc::SiteLoader.new.load
      assert_raises Nanoc::Errors::CannotCreateMultipleSnapshotsWithSameName do
        site.compile
      end
    end
  end

  def test_include_compiled_content_of_active_item_at_previous_snapshot
    with_site do
      # Create item
      File.write(
        'content/index.html',
        '[<%= @item.compiled_content(:snapshot => :aaa) %>]')

      # Create rules
      File.open('Rules', 'w') do |io|
        io.write "compile '/**/*' do\n"
        io.write "  snapshot :aaa\n"
        io.write "  filter :erb\n"
        io.write "  filter :erb\n"
        io.write "  write '/index.html'\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      # Compile
      site = Nanoc::SiteLoader.new.load
      site.compile

      # Check
      assert_equal '[[[<%= @item.compiled_content(:snapshot => :aaa) %>]]]',
        File.read('output/index.html')
    end
  end

  def test_mutually_include_compiled_content_at_previous_snapshot
    with_site do
      # Create items
      File.open('content/a.html', 'w') do |io|
        io.write('[<%= @items["/z.html"].compiled_content(:snapshot => :guts) %>]')
      end
      File.open('content/z.html', 'w') do |io|
        io.write('stuff')
      end

      # Create rules
      File.open('Rules', 'w') do |io|
        io.write "compile '/**/*' do\n"
        io.write "  snapshot :guts\n"
        io.write "  filter :erb\n"
        io.write "  write item.identifier\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      # Compile
      site = Nanoc::SiteLoader.new.load
      site.compile

      # Check
      assert_equal '[stuff]', File.read('output/a.html')
      assert_equal 'stuff', File.read('output/z.html')
    end
  end

  def test_layout_with_extra_filter_args
    with_site do |site|
      # Create item
      File.open('content/index.html', 'w') do |io|
        io.write('This is <%= @foo %>.')
      end

      # Create rules
      File.open('Rules', 'w') do |io|
        io.write "compile '/**/*' do\n"
        io.write "  filter :erb, :locals => { :foo => 123 }\n"
        io.write "  write '/index.html'\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      # Compile
      site = Nanoc::SiteLoader.new.load
      site.compile

      # Check
      assert_equal 'This is 123.', File.read('output/index.html')
    end
  end

  def test_change_routing_rule_and_recompile
    with_site do |site|
      # Create items
      File.open('content/a.html', 'w') do |io|
        io.write('<h1>A</h1>')
      end
      File.open('content/b.html', 'w') do |io|
        io.write('<h1>B</h1>')
      end

      # Create rules
      File.write('Rules', <<-EOS.gsub(/^ {8}/, ''))
        compile '/**/*' do
          if item.identifier == '/a.html'
            write '/index.html'
          end
        end
      EOS

      # Compile
      site = Nanoc::SiteLoader.new.load
      site.compile

      # Check
      assert_equal '<h1>A</h1>', File.read('output/index.html')

      # Create rules
      File.write('Rules', <<-EOS.gsub(/^ {8}/, ''))
        compile '/**/*' do
          if item.identifier == '/b.html'
            write '/index.html'
          end
        end
      EOS

      # Compile
      site = Nanoc::SiteLoader.new.load
      site.compile

      # Check
      assert_equal '<h1>B</h1>', File.read('output/index.html')
    end
  end

  def test_rep_assigns
    with_site do |site|
      # Create item
      File.open('content/index.html', 'w') do |io|
        io.write('@rep.name = <%= @rep.name %> - @item_rep.name = <%= @item_rep.name %>')
      end

      # Create rules
      File.open('Rules', 'w') do |io|
        io.write "compile '/**/*' do\n"
        io.write "  if @rep.name == :default && @item_rep.name == :default\n"
        io.write "    filter :erb\n"
        io.write "    write '/index.html'\n"
        io.write "  end\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      # Compile
      site = Nanoc::SiteLoader.new.load
      site.compile

      # Check
      assert_equal '@rep.name = default - @item_rep.name = default', File.read('output/index.html')
    end
  end

  def test_unfiltered_binary_item_should_not_be_moved_outside_content
    with_site do
      File.write('content/blah.dat', 'o hello')

      File.open('Rules', 'w') do |io|
        io.write "compile '/**/*' do\n"
        io.write "  write item.identifier\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      site = Nanoc::SiteLoader.new.load
      site.compile

      assert_equal Set.new(%w( content/blah.dat )), Set.new(Dir['content/*'])
      assert_equal Set.new(%w( output/blah.dat )), Set.new(Dir['output/*'])
    end
  end

  def test_tmp_text_items_are_removed_after_compilation
    with_site do |site|
      # Create item
      File.open('content/index.html', 'w') do |io|
        io.write('stuff')
      end

      # Compile
      site = Nanoc::SiteLoader.new.load
      site.compile

      # Check
      assert Dir['tmp/text_items/*'].empty?
    end
  end

end
