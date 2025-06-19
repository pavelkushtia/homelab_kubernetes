import { Producer } from 'kafkajs';
import { kafka } from '../config/kafka';

let producer: Producer | null = null;

export const initializeKafkaProducer = async (): Promise<void> => {
  try {
    producer = kafka.producer();
    await producer.connect();
    console.log('✅ Kafka producer connected');
  } catch (error) {
    console.error('❌ Kafka producer connection failed:', error);
  }
};

export const publishToKafka = async (topic: string, message: any): Promise<void> => {
  if (!producer) {
    console.warn('Kafka producer not initialized');
    return;
  }

  try {
    await producer.send({
      topic,
      messages: [
        {
          key: message.type || 'event',
          value: JSON.stringify(message),
          timestamp: Date.now().toString()
        }
      ]
    });
  } catch (error) {
    console.error(`Failed to publish to Kafka topic ${topic}:`, error);
    throw error;
  }
};

export const initializeKafkaConsumer = async (io: any) => {
  try {
    const consumer = kafka.consumer({ groupId: 'tweetstream-realtime' });
    await consumer.connect();
    
    await consumer.subscribe({ topics: ['tweets', 'user-activity', 'notifications'] });
    
    await consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          const data = JSON.parse(message.value!.toString());
          
          // Emit real-time updates via Socket.IO
          switch (topic) {
            case 'tweets':
              io.emit('tweet_update', data);
              break;
            case 'user-activity':
              io.emit('activity_update', data);
              break;
            case 'notifications':
              io.emit('notification', data);
              break;
          }
        } catch (error) {
          console.error('Error processing Kafka message:', error);
        }
      }
    });
    
    console.log('✅ Kafka consumer initialized');
  } catch (error) {
    console.error('❌ Kafka consumer initialization failed:', error);
  }
};

export const disconnectKafka = async (): Promise<void> => {
  if (producer) {
    await producer.disconnect();
    console.log('✅ Kafka producer disconnected');
  }
}; 