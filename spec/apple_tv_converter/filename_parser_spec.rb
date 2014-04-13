require 'spec_helper'

module AppleTvConverter
  describe FilenameParser do
    let(:parser) { FilenameParser.new(path) }

    describe "#show" do
      subject{ parser.show }

      context "for folder which contain only season number" do
        let(:path) { 'Cool Show/Season 1' }

        it "looks parent folder for show name" do
          expect(subject).to eq('Cool Show')
        end
      end
    end
  end
end
