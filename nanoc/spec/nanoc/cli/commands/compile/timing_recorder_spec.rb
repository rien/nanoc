# frozen_string_literal: true

describe Nanoc::CLI::Commands::CompileListeners::TimingRecorder, stdio: true do
  let(:listener) { described_class.new(reps: reps) }

  before { Timecop.freeze(Time.local(2008, 1, 2, 14, 5, 0)) }
  after { Timecop.return }

  before { Nanoc::CLI.verbosity = 2 }

  before { listener.start }
  after { listener.stop_safely }

  let(:reps) do
    Nanoc::Int::ItemRepRepo.new.tap do |reps|
      reps << rep
    end
  end

  let(:item) { Nanoc::Int::Item.new('<%= 1 + 2 %>', {}, '/hi.md') }

  let(:rep) do
    Nanoc::Int::ItemRep.new(item, :default).tap do |rep|
      rep.raw_paths = { default: ['/hi.html'] }
    end
  end

  let(:other_rep) do
    Nanoc::Int::ItemRep.new(item, :other).tap do |rep|
      rep.raw_paths = { default: ['/bye.html'] }
    end
  end

  it 'prints filters table' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:filtering_started, rep, :erb)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:filtering_ended, rep, :erb)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 14, 1))
    Nanoc::Int::NotificationCenter.post(:filtering_started, rep, :erb)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 14, 3))
    Nanoc::Int::NotificationCenter.post(:filtering_ended, rep, :erb)

    expect { listener.stop }
      .to output(/^\s*erb │     2   1\.00s   1\.50s   1\.90s   1\.95s   2\.00s   3\.00s$/).to_stdout
  end

  it 'records single from filtering_started to filtering_ended' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:filtering_started, rep, :erb)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:filtering_ended, rep, :erb)

    expect(listener.filters_summary.get('erb').min).to eq(1.00)
    expect(listener.filters_summary.get('erb').avg).to eq(1.00)
    expect(listener.filters_summary.get('erb').max).to eq(1.00)
    expect(listener.filters_summary.get('erb').sum).to eq(1.00)
    expect(listener.filters_summary.get('erb').count).to eq(1.00)
  end

  it 'records multiple from filtering_started to filtering_ended' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:filtering_started, rep, :erb)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:filtering_ended, rep, :erb)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 14, 1))
    Nanoc::Int::NotificationCenter.post(:filtering_started, rep, :erb)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 14, 3))
    Nanoc::Int::NotificationCenter.post(:filtering_ended, rep, :erb)

    expect(listener.filters_summary.get('erb').min).to eq(1.00)
    expect(listener.filters_summary.get('erb').avg).to eq(1.50)
    expect(listener.filters_summary.get('erb').max).to eq(2.00)
    expect(listener.filters_summary.get('erb').sum).to eq(3.00)
    expect(listener.filters_summary.get('erb').count).to eq(2.00)
  end

  it 'records filters in nested filtering_started/filtering_ended' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:filtering_started, rep, :outer)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:filtering_started, rep, :inner)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 3))
    Nanoc::Int::NotificationCenter.post(:filtering_ended, rep, :inner)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 6))
    Nanoc::Int::NotificationCenter.post(:filtering_ended, rep, :outer)

    expect(listener.filters_summary.get('inner').min).to eq(2.00)
    expect(listener.filters_summary.get('inner').avg).to eq(2.00)
    expect(listener.filters_summary.get('inner').max).to eq(2.00)
    expect(listener.filters_summary.get('inner').sum).to eq(2.00)
    expect(listener.filters_summary.get('inner').count).to eq(1.00)

    expect(listener.filters_summary.get('outer').min).to eq(6.00)
    expect(listener.filters_summary.get('outer').avg).to eq(6.00)
    expect(listener.filters_summary.get('outer').max).to eq(6.00)
    expect(listener.filters_summary.get('outer').sum).to eq(6.00)
    expect(listener.filters_summary.get('outer').count).to eq(1.00)
  end

  it 'pauses outer stopwatch when suspended' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:compilation_started, rep)
    Nanoc::Int::NotificationCenter.post(:filtering_started, rep, :outer)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:filtering_started, rep, :inner)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 3))
    Nanoc::Int::NotificationCenter.post(:compilation_suspended, rep, :__anything__)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 6))
    Nanoc::Int::NotificationCenter.post(:compilation_started, rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 10))
    Nanoc::Int::NotificationCenter.post(:filtering_ended, rep, :inner)
    Nanoc::Int::NotificationCenter.post(:filtering_ended, rep, :outer)

    expect(listener.filters_summary.get('outer').min).to eq(7.00)
    expect(listener.filters_summary.get('outer').avg).to eq(7.00)
    expect(listener.filters_summary.get('outer').max).to eq(7.00)
    expect(listener.filters_summary.get('outer').sum).to eq(7.00)
    expect(listener.filters_summary.get('outer').count).to eq(1.00)
  end

  it 'records single from filtering_started over compilation_{suspended,started} to filtering_ended' do
    Nanoc::Int::NotificationCenter.post(:compilation_started, rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:filtering_started, rep, :erb)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:compilation_suspended, rep, :__anything__)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 3))
    Nanoc::Int::NotificationCenter.post(:compilation_started, rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 7))
    Nanoc::Int::NotificationCenter.post(:filtering_ended, rep, :erb)

    expect(listener.filters_summary.get('erb').min).to eq(5.00)
    expect(listener.filters_summary.get('erb').avg).to eq(5.00)
    expect(listener.filters_summary.get('erb').max).to eq(5.00)
    expect(listener.filters_summary.get('erb').sum).to eq(5.00)
    expect(listener.filters_summary.get('erb').count).to eq(1.00)
  end

  it 'records single phase start+stop' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:phase_started, 'donkey', rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:phase_ended, 'donkey', rep)

    expect(listener.phases_summary.get('donkey').min).to eq(1.00)
    expect(listener.phases_summary.get('donkey').avg).to eq(1.00)
    expect(listener.phases_summary.get('donkey').max).to eq(1.00)
    expect(listener.phases_summary.get('donkey').sum).to eq(1.00)
    expect(listener.phases_summary.get('donkey').count).to eq(1.00)
  end

  it 'records multiple phase start+stop' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:phase_started, 'donkey', rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:phase_ended, 'donkey', rep)
    Timecop.freeze(Time.local(2008, 9, 1, 11, 6, 0))
    Nanoc::Int::NotificationCenter.post(:phase_started, 'donkey', rep)
    Timecop.freeze(Time.local(2008, 9, 1, 11, 6, 2))
    Nanoc::Int::NotificationCenter.post(:phase_ended, 'donkey', rep)

    expect(listener.phases_summary.get('donkey').min).to eq(1.00)
    expect(listener.phases_summary.get('donkey').avg).to eq(1.50)
    expect(listener.phases_summary.get('donkey').max).to eq(2.00)
    expect(listener.phases_summary.get('donkey').sum).to eq(3.00)
    expect(listener.phases_summary.get('donkey').count).to eq(2.00)
  end

  it 'records single phase start+yield+resume+stop' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:phase_started, 'donkey', rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:phase_yielded, 'donkey', rep)
    Timecop.freeze(Time.local(2008, 9, 1, 11, 6, 0))
    Nanoc::Int::NotificationCenter.post(:phase_resumed, 'donkey', rep)
    Timecop.freeze(Time.local(2008, 9, 1, 11, 6, 2))
    Nanoc::Int::NotificationCenter.post(:phase_ended, 'donkey', rep)

    expect(listener.phases_summary.get('donkey').min).to eq(3.00)
    expect(listener.phases_summary.get('donkey').avg).to eq(3.00)
    expect(listener.phases_summary.get('donkey').max).to eq(3.00)
    expect(listener.phases_summary.get('donkey').sum).to eq(3.00)
    expect(listener.phases_summary.get('donkey').count).to eq(1.00)
  end

  it 'records single phase start+yield+abort+start+stop' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:phase_started, 'donkey', rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:phase_yielded, 'donkey', rep)
    Timecop.freeze(Time.local(2008, 9, 1, 11, 6, 0))
    Nanoc::Int::NotificationCenter.post(:phase_aborted, 'donkey', rep)
    Timecop.freeze(Time.local(2008, 9, 1, 12, 7, 2))
    Nanoc::Int::NotificationCenter.post(:phase_started, 'donkey', rep)
    Timecop.freeze(Time.local(2008, 9, 1, 12, 7, 5))
    Nanoc::Int::NotificationCenter.post(:phase_ended, 'donkey', rep)

    expect(listener.phases_summary.get('donkey').min).to eq(1.00)
    expect(listener.phases_summary.get('donkey').avg).to eq(2.00)
    expect(listener.phases_summary.get('donkey').max).to eq(3.00)
    expect(listener.phases_summary.get('donkey').sum).to eq(4.00)
    expect(listener.phases_summary.get('donkey').count).to eq(2.00)
  end

  it 'records stage duration' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:stage_started, 'donkey', rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:stage_ended, 'donkey', rep)

    expect(listener.stages_summary.get('donkey').sum).to eq(1.00)
    expect(listener.stages_summary.get('donkey').count).to eq(1.00)
  end

  it 'prints stage durations' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:stage_started, 'donkey', rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:stage_ended, 'donkey', rep)

    expect { listener.stop }
      .to output(/^\s*donkey │ 1\.00s$/).to_stdout
  end

  it 'prints out outdatedness rule durations' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:outdatedness_rule_started, Nanoc::Int::OutdatednessRules::CodeSnippetsModified, rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:outdatedness_rule_ended, Nanoc::Int::OutdatednessRules::CodeSnippetsModified, rep)

    expect { listener.stop }
      .to output(/^\s*CodeSnippetsModified │     1   1\.00s   1\.00s   1\.00s   1\.00s   1\.00s   1\.00s$/).to_stdout
  end

  it 'records single outdatedness rule duration' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:outdatedness_rule_started, Nanoc::Int::OutdatednessRules::CodeSnippetsModified, rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:outdatedness_rule_ended, Nanoc::Int::OutdatednessRules::CodeSnippetsModified, rep)

    expect(listener.outdatedness_rules_summary.get('CodeSnippetsModified').min).to eq(1.00)
    expect(listener.outdatedness_rules_summary.get('CodeSnippetsModified').avg).to eq(1.00)
    expect(listener.outdatedness_rules_summary.get('CodeSnippetsModified').max).to eq(1.00)
    expect(listener.outdatedness_rules_summary.get('CodeSnippetsModified').sum).to eq(1.00)
    expect(listener.outdatedness_rules_summary.get('CodeSnippetsModified').count).to eq(1.00)
  end

  it 'records multiple outdatedness rule duration' do
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 0))
    Nanoc::Int::NotificationCenter.post(:outdatedness_rule_started, Nanoc::Int::OutdatednessRules::CodeSnippetsModified, rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 5, 1))
    Nanoc::Int::NotificationCenter.post(:outdatedness_rule_ended, Nanoc::Int::OutdatednessRules::CodeSnippetsModified, rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 6, 0))
    Nanoc::Int::NotificationCenter.post(:outdatedness_rule_started, Nanoc::Int::OutdatednessRules::CodeSnippetsModified, other_rep)
    Timecop.freeze(Time.local(2008, 9, 1, 10, 6, 3))
    Nanoc::Int::NotificationCenter.post(:outdatedness_rule_ended, Nanoc::Int::OutdatednessRules::CodeSnippetsModified, other_rep)

    expect(listener.outdatedness_rules_summary.get('CodeSnippetsModified').min).to eq(1.00)
    expect(listener.outdatedness_rules_summary.get('CodeSnippetsModified').avg).to eq(2.00)
    expect(listener.outdatedness_rules_summary.get('CodeSnippetsModified').max).to eq(3.00)
    expect(listener.outdatedness_rules_summary.get('CodeSnippetsModified').sum).to eq(4.00)
    expect(listener.outdatedness_rules_summary.get('CodeSnippetsModified').count).to eq(2.00)
  end

  it 'skips printing empty metrics' do
    expect { listener.stop }
      .not_to output(/filters|phases|stages/).to_stdout
  end
end
