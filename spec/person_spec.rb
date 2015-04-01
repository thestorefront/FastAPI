describe Person do
  it_behaves_like 'fastapi_model'

  describe 'when locating a specific person' do
    let!(:person)  { create(:example_person) }
    let(:response) { ModelHelper.response(Person, name: 'Example Person') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age buckets) } }
    end
  end

  describe 'when filtering through many people' do
    let!(:people)  { create_list(:person, 15) }
    let(:response) { ModelHelper.response(Person, age__gte: 0) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 15, count: 15, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age buckets) } }
    end
  end

  describe 'when whitelisting person attributes' do
    let!(:person) { create(:person) }
    let(:response) { ModelHelper.whitelisted_response(Person, 'created_at') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age buckets created_at) } }
    end
  end

  describe 'when locating a person associated with a bucket' do
    let!(:person)            { create(:person_with_buckets) }
    let(:response)           { ModelHelper.response(Bucket) }
    let(:person_from_bucket) { response['data'].first['person'] }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 5, count: 5, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { data: person_from_bucket, attributes: %w(id name gender age) } }
    end
  end
end
