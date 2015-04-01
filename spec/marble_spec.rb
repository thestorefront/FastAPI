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

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { data: response['data'].first['marbles'].first,
                         attributes: %w(id color radius) } }
    end
  end
end
