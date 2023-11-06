import { PineconeClient } from '@pinecone-database/pinecone'

export const getPineconeClient = async () => {
  const client = new PineconeClient()

  await client.init({
    environment: 'us-west4-gcp',
    apiKey: process.env.PINECONE_API_KEY!,
  })

  return client
}

// import { Pinecone } from "@pinecone-database/pinecone";      

// const pinecone = new Pinecone();      
// await pinecone.init({      
// 	environment: "gcp-starter",      
// 	apiKey: "431c46e9-3780-45ab-bf72-492ab69aed0b",      
// });      
// const index = pinecone.Index("ampdent");