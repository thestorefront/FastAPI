describe Bucket do
  it_behaves_like 'fastapi_model'

  describe 'when locating a specific bucket' do
    let!(:bucket)  { create(:red_plastic_bucket) }
    let(:response) { ModelHelper.response(Bucket, color: 'red', material: 'plastic') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color material person marbles) } }
    end
  end

  describe 'when filtering through many buckets' do
    let!(:red_buckets)  { create_list(:red_plastic_bucket, 15) }
    let!(:blue_buckets) { create_list(:blue_paper_bucket, 15) }
    let(:response)      { ModelHelper.response(Bucket, color: 'red') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 15, count: 15, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color material person marbles) } }
    end
  end

  describe 'when whitelisting bucket attributes' do
    let!(:bucket) { create(:bucket) }
    let(:response) { ModelHelper.whitelisted_response(Bucket, 'created_at') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color material person marbles created_at) } }
    end
  end

  describe 'when filtering through many buckets using a default filter on nested marbles' do
    let!(:buckets_5)  { create_list(:bucket_with_marbles, 5, marble_radius: 5) }
    let!(:buckets_15) { create_list(:bucket_with_marbles, 5, marble_radius: 15) }
    let(:response)    { ModelHelper.response(Bucket) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 10, count: 10, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color material person marbles) } }
    end

    it 'returns only marbles that match the default filter' do
      max_radius = response['data'].map { |b| b['marbles'].map { |m| m['radius' ] } }.flatten.max
      expect(max_radius <= 10).to be_truthy
    end
  end

  describe 'when locating a bucket by id' do
    let!(:bucket)        { create(:bucket) }
    let(:response)       { ModelHelper.fetch(Bucket, bucket.id) }
    let(:fetched_bucket) { response['data'].first }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color material person marbles) } }
    end

    it 'has the correct id' do
      expect(fetched_bucket['id']).to eq bucket.id
    end
  end

  describe 'when locating a bucket that does not exist by id' do
    let(:response) { ModelHelper.fetch(Bucket, 100) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 0, count: 0, offset: 0, error: /[\w]+ id does not exist/ } }
    end

    it 'has an empty data array' do
      expect(response['data']).to eq []
    end
  end

  describe 'when locating a bucket associated with a person' do
    let!(:person)  { create(:person_with_buckets) }
    let(:response) { ModelHelper.response(Person) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { data: response['data'].first['buckets'].first,
                         attributes: %w(id color material) } }
    end
  end

  describe 'when locating an incomplete bucket associated with a person' do
    let!(:person)           { create(:person_with_incomplete_bucket) }
    let(:response)          { ModelHelper.response(Person) }
    let(:incomplete_bucket) { response['data'].first['buckets'].first }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { data: incomplete_bucket, attributes: %w(id color material) } }
    end

    it 'has a nil color' do
      expect(incomplete_bucket['color']).to be_nil
    end

    it 'has the correct material' do
      expect(incomplete_bucket['material']).to eq 'plastic'
    end
  end

  describe 'when spoofing a bucket with no meta' do
    let(:bucket)   { Bucket.fastapi.spoof([{id: 1, color: 'blue' }]) }
    let(:response) { JSON.parse(bucket) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color) } }
    end
  end

  describe 'when spoofing a bucket with custom meta' do
    let(:bucket)   { Bucket.fastapi.spoof([{id: 1, color: 'blue' }], { count: 10, total: 10 }) }
    let(:response) { JSON.parse(bucket) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 10, count: 10, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color) } }
    end
  end
end
