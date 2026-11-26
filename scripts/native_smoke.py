import sys
sys.path.insert(0, '.')
from grpcdc.kafka_native import NativeKafkaClient
from grpcdc import kafka_pb
broker = sys.argv[1] if len(sys.argv) > 1 else '127.0.0.1:19092'
c = NativeKafkaClient(broker)
md = c.Metadata(kafka_pb.MetadataRequest())
print('brokers:', len(md.brokers))
r = c.CreateTopics(kafka_pb.CreateTopicsRequest(topics=[kafka_pb.NewTopic(name='native-smoke', num_partitions=1, replication_factor=1)]))
assert all(t.error_code == 0 for t in r.topics), r
g = c.ListGroups(kafka_pb.ListGroupsRequest())
print('groups ok:', g.error_code)
print('native_smoke: OK')
