describe Beverage do
  it_behaves_like 'fastapi_model'

  describe 'when locating a specific beverage' do
    let!(:beverage) { create(:water) }
    let(:response)  { ModelHelper.response(Beverage, name: 'water') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name flavors dish) } }
    end
  end
end
