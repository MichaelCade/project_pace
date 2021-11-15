echo "Add Data to MongoDB"
kubectl exec -ti my-release-mongodb-0 -n mongo-test -- bash
mongo admin --authenticationDatabase admin -u root -p $MONGODB_ROOT_PASSWORD --quiet --eval "db.restaurants.insert({'name' : 'Roys', 'cuisine' : 'Hawaiian', 'id' : '8675309'})"
mongo admin --authenticationDatabase admin -u root -p $MONGODB_ROOT_PASSWORD --quiet --eval "db.restaurants.find()"
exit 