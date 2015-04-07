describe Marble do
  it_behaves_like 'fastapi_model'

  describe 'when locating a specific marble' do
    let!(:marble)  { create(:blue_marble) }
    let(:response) { ModelHelper.response(Marble, color: 'blue') }

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
    let(:response)      { ModelHelper.response(Marble, color: 'red') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 5, count: 5, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color radius bucket) } }
    end
  end

  describe 'when whitelisting marble attributes' do
    let!(:marble) { create(:marble) }
    let(:response) { ModelHelper.response(Marble, {}, whitelist: 'created_at') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color radius bucket created_at) } }
    end
  end

  describe 'when filtering through marbles using a default filter' do
    let!(:orange_marble) { create(:marble, color: 'orange') }
    let!(:clear_marble)  { create(:marble, color: 'clear') }
    let(:response)       { ModelHelper.response(Marble) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color radius bucket) } }
    end
  end

  describe 'when locating a marble by id' do
    let!(:marble)        { create(:marble) }
    let(:response)       { ModelHelper.fetch(Marble, marble.id) }
    let(:fetched_bucket) { response['data'].first }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color radius bucket) } }
    end

    it 'has the correct id' do
      expect(fetched_bucket['id']).to eq marble.id
    end
  end

  describe 'when locating a marble that does not exist by id' do
    let(:response) { ModelHelper.fetch(Marble, 100) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 0, count: 0, offset: 0, error: /[\w]+ id does not exist/ } }
    end

    it 'has an empty data array' do
      expect(response['data']).to eq []
    end
  end

  describe 'when locating a marble associated with a bucket' do
    let!(:bucket)  { create(:bucket_with_marbles) }
    let(:response) { ModelHelper.response(Bucket) }
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
    let(:response)          { ModelHelper.response(Bucket) }
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
