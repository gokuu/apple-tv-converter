require 'spec_helper'

module AppleTvConverter
  describe FilenameParser do
    let(:parser) { FilenameParser.new(path) }

    describe "#tvshow_name" do
      subject{ parser.tvshow_name }

      context "for folder which contain only season number" do
        let(:path) { 'Cool Show/Season 1/file 1.avi' }

        it "looks parent folder for show name" do
          expect(subject).to eq('Cool Show')
        end
      end

      context "for folder which doesn't contain season number" do
        let(:path) { 'Cool Show/file 1.avi' }

        it "uses whole name of folder as show name" do
          expect(subject).to eq('Cool Show')
        end
      end
    end

    shared_examples_for 'parses values' do |season, episode, last_episode|
      describe "#season_number" do
        subject{ parser.season_number }

        it "returns parsed season number" do
          expect(subject).to eq(season)
        end
      end

      describe "#episode_number" do
        subject{ parser.episode_number }

        it "returns parsed episode number" do
          expect(subject).to eq(episode)
        end
      end

      describe "#last_episode_number" do
        subject{ parser.last_episode_number }

        it "returns parsed last episode number" do
          expect(subject).to eq(last_episode)
        end
      end
    end

    context "if file doesn't contain in any know format" do
      let(:path) { 'Cool Show/Cool Show.avi' }

      it_behaves_like 'parses values', nil, nil, nil
    end

    context "if file name contains season/episode number in format S01E01" do
      let(:path) { 'Cool Show/Cool Show s01e02.avi' }

      it_behaves_like 'parses values', 1, 2, nil
    end

    context "if file name contains season/episode number in format S01E02(E03)+" do
      let(:path) { 'Cool Show/Cool Show s01e02e03e04.avi' }

      it_behaves_like 'parses values', 1, 2, 4
    end

    context "if file name contains season/episode number in format S01E02(-E03)+" do
      let(:path) { 'Cool Show/Cool Show s01e02-e04.avi' }

      it_behaves_like 'parses values', 1, 2, 4
    end

    context "if file name contains season/episode number in format S01E02(-03)+" do
      let(:path) { 'Cool Show/Cool Show s01e02-04.avi' }

      it_behaves_like 'parses values', 1, 2, 4
    end

    context "if file name contains season/episode number in format 1x02" do
      let(:path) { 'Cool Show/Cool Show 01x02.avi' }

      it_behaves_like 'parses values', 1, 2, nil
    end

    context "if file name contains season/episode number in format 1x02(_0x03)+" do
      let(:path) { 'Cool Show/Cool Show 01x02_01x04.avi' }

      it_behaves_like 'parses values', 1, 2, 4
    end

    context "if file name contains episode number in format 1_of_12" do
      let(:path) { 'Cool Show/Cool Show [1_of_12].avi' }

      it_behaves_like 'parses values', nil, 1, nil
    end

    context "if file name contains episode number in format 1of12" do
      let(:path) { 'Cool Show/Cool Show 1of12.avi' }

      it_behaves_like 'parses values', nil, 1, nil
    end
  end
end
