describe Dish do
  it_behaves_like 'fastapi_model'

  describe 'when locating a specific dish' do
    let!(:dish)    { create(:burrito) }
    let(:response) { ModelHelper.response(Dish, name: 'burrito') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name ingredients person beverage) } }
    end
  end

  describe 'when locating a dish by ingredient using in' do
    let!(:cheeseburger)    { create(:cheeseburger) }
    let!(:margarita_pizza) { create(:margarita_pizza) }
    let(:response)         { ModelHelper.response(Dish, ingredients__contains: ['pickle']) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name ingredients person beverage) } }
    end

    it 'contains pickles' do
      expect(response['data'].first['ingredients']).to include('pickle')
    end
  end

  describe 'when locating a dish by ingredient using intersects' do
    let!(:cheeseburger)    { create(:cheeseburger) }
    let!(:margarita_pizza) { create(:margarita_pizza) }
    let(:response)         { ModelHelper.response(Dish, ingredients__intersects: ['basil']) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name ingredients person beverage) } }
    end

    it 'contains pickles' do
      expect(response['data'].first['ingredients']).to include('basil')
    end
  end

  describe 'when locating a beverage associated with a dish' do
    let!(:dish)    { create(:burrito_with_coke) }
    let(:response) { ModelHelper.response(Dish, name: 'burrito') }
    let(:beverage) { response['data'].first['beverage'] }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { data: beverage, attributes: %w(id name flavors) } }
    end

    it 'has the right flavors' do
      expect(beverage['flavors'].sort).to eq %w(sweet vanilla cinnamon orange lime lemon nutmeg).sort
    end
  end
end
