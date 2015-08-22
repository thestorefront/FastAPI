describe Pet do
  describe 'using a custom table name' do
    it_behaves_like 'fastapi_model'

    describe 'when locating a specific pet' do
      let!(:pet)        { create(:red_pet) }
      let(:response)    { ModelHelper.response(Pet, color: 'red') }
      let(:fetched_pet) { response['data'].first }

      it_behaves_like 'fastapi_meta' do
        let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
      end

      it_behaves_like 'fastapi_data' do
        let(:expected) { { attributes: %w(peoples_pets_id name color owner) } }
      end

      it 'has the correct color' do
        expect(fetched_pet['color']).to eq pet.color
      end

      it 'has the correct name' do
        expect(fetched_pet['name']).to eq pet.name
      end
    end

    describe 'when filtering through many pets' do
      let!(:red_pets)   { create_list(:red_pet, 5) }
      let!(:brown_pets) { create_list(:brown_pet, 5) }
      let(:response)    { ModelHelper.response(Pet, color: 'brown') }

      it_behaves_like 'fastapi_meta' do
        let(:expected) { { total: 5, count: 5, offset: 0, error: false } }
      end

      it_behaves_like 'fastapi_data' do
        let(:expected) { { attributes: %w(peoples_pets_id name color owner) } }
      end
    end

    describe 'when locating a pet by id' do
      let!(:pet)        { create(:pet) }
      let(:response)    { ModelHelper.fetch(Pet, pet.id) }
      let(:fetched_pet) { response['data'].first }

      it_behaves_like 'fastapi_meta' do
        let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
      end

      it_behaves_like 'fastapi_data' do
        let(:expected) { { attributes: %w(peoples_pets_id name color owner) } }
      end

      it 'has the correct id' do
        expect(fetched_pet['peoples_pets_id']).to eq pet.peoples_pets_id
      end
    end

    describe 'when locating a pet that does not exist by id' do
      let(:response) { ModelHelper.fetch(Pet, 100) }

      it_behaves_like 'fastapi_meta' do
        let(:expected) { { total: 0, count: 0, offset: 0, error: /\w+ with peoples_pets_id: \d+ does not exist/ } }
      end

      it 'has an empty data array' do
        expect(response['data']).to eq []
      end
    end

    describe 'when locating a pet associated with a person' do
      let!(:person)         { create(:person_with_pets) }
      let(:response)        { ModelHelper.response(Person) }
      let(:pet_from_person) { response['data'].first['pets'].first }

      it_behaves_like 'fastapi_meta' do
        let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
      end

      it_behaves_like 'fastapi_data' do
        let(:expected) { { data: pet_from_person, attributes: %w(peoples_pets_id name color) } }
      end
    end
  end
end
