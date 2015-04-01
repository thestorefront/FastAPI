shared_examples 'fastapi_model' do
  it 'responds to fastapi' do
    expect(subject.class).to respond_to(:fastapi)
  end
end
