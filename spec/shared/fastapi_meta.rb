shared_examples 'fastapi_meta' do
  describe 'meta' do
    let(:meta) { response['meta'] }

    it 'is expected to exist' do
      expect(meta).to be_truthy
    end

    it 'has a correct total' do
      expect(meta['total']).to eq expected[:total]
    end

    it 'has a correct count' do
      expect(meta['count']).to eq expected[:count]
    end

    it 'has a correct offset' do
      expect(meta['offset']).to eq expected[:offset]
    end

    it 'should have the correct error (or no error)' do
      if expected[:error]
        expect(meta['error']['message']).to match(expected[:error])
      else
        expect(meta['error']).to be_nil
      end
    end
  end
end
