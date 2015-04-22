shared_examples 'fastapi_model' do
  it 'responds to fastapi' do
    expect(subject.class).to respond_to(:fastapi)
  end

  it 'responds to fastapi.data' do
    expect(subject.class.fastapi).to respond_to(:data)
  end

  it 'responds to fastapi.data_json' do
    expect(subject.class.fastapi).to respond_to(:data_json)
  end

  it 'responds to fastapi.meta' do
    expect(subject.class.fastapi).to respond_to(:meta)
  end

  it 'responds to fastapi.meta_json' do
    expect(subject.class.fastapi).to respond_to(:meta_json)
  end

  it 'responds to fastapi.to_hash' do
    expect(subject.class.fastapi).to respond_to(:to_hash)
  end

  describe 'when calling fastapi.reject' do
    it 'responds to fastapi.reject' do
      expect(subject.class.fastapi).to respond_to(:reject)
    end

    it 'forms the default rejection response' do
      response = Oj.load(subject.class.fastapi.reject)
      message  = response['meta']['error']['message']
      expect(message).to eq 'Access denied'
    end

    it 'allows specifying the rejection response message' do
      custom   = "I'm sorry, Dave. I'm afraid I can't do that."
      response = Oj.load(subject.class.fastapi.reject(custom))
      message  = response['meta']['error']['message']
      expect(message).to eq custom
    end
  end
end
