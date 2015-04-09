describe Dish do
  it_behaves_like 'fastapi_model'

  describe 'when locating a specific dish' do
    let!(:dish)    { create(:burrito) }
    let(:response) { ModelHelper.response(Dish, name: 'burrito' ) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name ingredients) } }
    end
  end

  describe 'when locating a dish by ingredient' do
    let!(:cheeseburger)    { create(:cheeseburger) }
    let!(:margarita_pizza) { create(:margarita_pizza) }
    let(:response)         { ModelHelper.response(Dish, ingredients: 'pickle') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name ingredients) } }
    end

    it 'contains pickles' do
      expect(response['data'].first['ingredients']).to include('pickle')
    end
  end
end
