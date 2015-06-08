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

  describe 'when locating beverages with out a dish' do
    let!(:beverage) { create(:coke) }
    let(:response)  { ModelHelper.response(Beverage, dish_id: nil) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name flavors dish) } }
    end
  end

  describe 'when locating a beverage using not' do
    let!(:water)   { create(:water) }
    let!(:coke)    { create(:coke) }
    let(:response) { ModelHelper.response(Beverage, name__not: 'water') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name flavors dish) } }
    end

    it 'has the correct name' do
      expect(response['data'].first['name']).to eq 'Coca-Cola'
    end
  end

  describe 'when locating a beverage using string contains' do
    let!(:water)   { create(:water) }
    let!(:coke)    { create(:coke) }
    let(:response) { ModelHelper.response(Beverage, name__like: 'wat') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name flavors dish) } }
    end

    it 'has the correct name' do
      expect(response['data'].first['name']).to eq 'water'
    end
  end

  describe 'when locating a beverage using case insensitive string contains' do
    let!(:water)   { create(:water) }
    let!(:coke)    { create(:coke) }
    let(:response) { ModelHelper.response(Beverage, name__ilike: 'CoCa') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name flavors dish) } }
    end

    it 'has the correct name' do
      expect(response['data'].first['name']).to eq 'Coca-Cola'
    end
  end

  describe 'when locating a beverage using not null' do
    let!(:null_drink) { create(:beverage, name: nil) }
    let!(:beer)       { create(:beer) }
    let(:response)    { ModelHelper.response(Beverage, name__not_null: nil) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name flavors dish) } }
    end

    it 'has the correct name' do
      expect(response['data'].first['name']).to eq 'Hell Or High Watermelon'
    end
  end

  describe 'when locating a beverage by using in an array' do
    let!(:water)   { create(:water) }
    let!(:coke)    { create(:coke) }
    let(:response) { ModelHelper.response(Beverage, name__in: ['water', 'Coca-Cola']) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 2, count: 2, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name flavors dish) } }
    end
  end

  describe 'when locating a beverage using not in' do
    let!(:water)   { create(:water) }
    let!(:coke)    { create(:coke) }
    let(:response) { ModelHelper.response(Beverage, flavors__not_contains: ['lime']) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name flavors dish) } }
    end

    it 'has the correct name' do
      expect(response['data'].first['name']).to eq 'water'
    end
  end
end
