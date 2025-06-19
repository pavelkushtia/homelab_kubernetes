import { Kafka, Producer, Consumer } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'tweetstream-backend',
  brokers: [process.env.KAFKA_BROKER || 'kafka.platform-services.svc.cluster.local:9092'],
  retry: {
    initialRetryTime: 100,
    retries: 8
  }
});

const producer: Producer = kafka.producer();
const consumer: Consumer = kafka.consumer({ groupId: 'tweetstream-group' });

// Initialize Kafka connections
const connectKafka = async (): Promise<void> => {
  try {
    await producer.connect();
    await consumer.connect();
    
    await consumer.subscribe({ 
      topics: ['tweets', 'notifications', 'user-activity'],
      fromBeginning: false
    });
    
    console.log('✅ Connected to Kafka platform service');
  } catch (error) {
    console.error('❌ Failed to connect to Kafka:', error);
  }
};

const disconnectKafka = async (): Promise<void> => {
  try {
    await producer.disconnect();
    await consumer.disconnect();
    console.log('✅ Kafka connections closed');
  } catch (error) {
    console.error('❌ Error disconnecting from Kafka:', error);
  }
};

export { kafka, producer, consumer, connectKafka, disconnectKafka }; 