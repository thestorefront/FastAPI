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
end
