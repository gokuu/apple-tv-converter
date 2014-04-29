require 'spec_helper'

module AppleTvConverter
  describe Media do
    context "when data file exists" do
      let(:media) { Media.new }
      let(:data_file) { '.apple-tv-converter.data' }

      let(:data_tvdb_id)   { "data_tvdb_id" }
      let(:option_tvdb_id) { "option_tvdb_id" }
      let(:data_imdb_id)   { "data_imdb_id" }
      let(:option_imdb_id) { "option_imdb_id" }
      let(:data_episode_number_padding)   { "data_episode_number_padding" }
      let(:option_episode_number_padding) { "option_episode_number_padding" }
      let(:data_use_absolute_episode_numbering)   { "data_use_absolute_episode_numbering" }
      let(:option_use_absolute_episode_numbering) { "option_use_absolute_episode_numbering" }

      let(:data) do
        {
          imdb_id: data_imdb_id,
          tvdb_id: data_tvdb_id,
          episode_number_padding: data_episode_number_padding,
          use_absolute_episode_numbering: data_use_absolute_episode_numbering
        }
      end

      before :each do
        allow(media).to receive(:data_file).and_return(data_file)
        allow(media).to receive(:has_data_file?).and_return(true)
        allow(YAML).to receive(:load_file).with(media.data_file).and_return(data)
      end

      subject{ media.send(:load_data_file) }

      context "for option tvdb_id" do
        it "reads from file" do
          expect{ subject }.to change(media, :tvdb_id).to(data_tvdb_id)
        end

        context "already set" do
          before{ media.tvdb_id = option_tvdb_id }

          it "doesn't read from file" do
            expect{ subject }.to_not change(media, :tvdb_id).from(option_tvdb_id)
          end
        end
      end

      context "for option imdb_id" do
        it "reads from file" do
          expect{ subject }.to change(media, :imdb_id).to(data_imdb_id)
        end

        context "already set" do
          before{ media.imdb_id = option_imdb_id }

          it "doesn't read from file" do
            expect{ subject }.to_not change(media, :imdb_id).from(option_imdb_id)
          end
        end
      end

      context "for option episode_number_padding" do
        it "reads from file" do
          expect{ subject }.to change(media, :episode_number_padding).to(data_episode_number_padding)
        end

        context "already set" do
          before{ media.episode_number_padding = option_episode_number_padding }

          it "doesn't read from file" do
            expect{ subject }.to_not change(media, :episode_number_padding).from(option_episode_number_padding)
          end
        end
      end

      context "for option use_absolute_episode_numbering" do
        it "reads from file" do
          expect{ subject }.to change(media, :use_absolute_episode_numbering).to(data_use_absolute_episode_numbering)
        end

        context "already set" do
          before{ media.use_absolute_episode_numbering = option_use_absolute_episode_numbering }

          it "doesn't read from file" do
            expect{ subject }.to_not change(media, :use_absolute_episode_numbering).from(option_use_absolute_episode_numbering)
          end
        end
      end
    end
  end
end
