describe Marble do
  it_behaves_like 'fastapi_model'

  describe 'when locating a specific marble' do
    let!(:marble)  { create(:blue_marble) }
    let(:response) { ModelHelper.get_response(subject.class, color: 'blue') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color radius bucket) } }
    end
  end

  describe 'when filtering through many marbles' do
    let!(:blue_marbles) { create_list(:blue_marble, 5) }
    let!(:red_marbles)  { create_list(:red_marble, 5) }
    let(:response)      { ModelHelper.get_response(subject.class, color: 'red') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 5, count: 5, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color radius bucket) } }
    end
  end

  describe 'when locating a marble associated with a bucket' do
    let!(:bucket)  { create(:bucket_with_marbles) }
    let(:response) { ModelHelper.get_response(Bucket) }
    let(:marble)   { response['data'].first['marbles'].first }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { data: marble, attributes: %w(id color radius) } }
    end
  end

  describe 'when locating an incomplete marble associated with a person' do
    let!(:bucket)           { create(:bucket_with_incomplete_marble) }
    let(:response)          { ModelHelper.get_response(Bucket) }
    let(:incomplete_marble) { response['data'].first['marbles'].first }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { data: incomplete_marble, attributes: %w(id color radius)}}
    end

    it 'has a nil color' do
      expect(incomplete_marble['color']).to be_nil
    end

    it 'has the correct radius' do
      expect(incomplete_marble['radius']).to eq 5
    end
  end
end
