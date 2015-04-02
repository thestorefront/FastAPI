shared_examples 'fastapi_data' do
  describe 'data' do
    let(:data) { expected[:data] || response['data'].first }

    it 'only includes specified attributes' do
      expect(data.keys.sort).to eq(expected[:attributes].sort)
    end
  end
end
