describe Bucket do
  it_behaves_like 'fastapi_model'

  describe 'when locating a specific bucket' do
    let!(:bucket)  { create(:red_plastic_bucket) }
    let(:response) { ModelHelper.get_response(subject.class, color: 'red', material: 'plastic') }

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
    let(:response)      { ModelHelper.get_response(subject.class, color: 'red') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 15, count: 15, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color material person marbles) } }
    end
  end

  describe 'when filtering through many buckets using the default filters' do
    let!(:buckets_5)  { create_list(:bucket_with_marbles, 5, marble_radius: 5) }
    let!(:buckets_15) { create_list(:bucket_with_marbles, 5, marble_radius: 15) }
    let(:response)    { ModelHelper.get_response(subject.class) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 5, count: 5, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id color material person marbles) } }
    end
  end

  describe 'when locating a bucket associated with a person' do
    let!(:person)  { create(:person_with_buckets) }
    let(:response) { ModelHelper.get_response(Person) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { data: response['data'].first['buckets'].first,
                         attributes: %w(id color material) } }
    end
  end
end
