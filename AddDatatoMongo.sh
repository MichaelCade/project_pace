echo "Add Data to MongoDB"

echo "Add the following lines into the context of the container to add data" 
echo "mongo admin --authenticationDatabase admin -u root -p $MONGODB_ROOT_PASSWORD --quiet --eval "db.restaurants.insert({'name' : 'Roys', 'cuisine' : 'Hawaiian', 'id' : '8675309'})""
echo "mongo admin --authenticationDatabase admin -u root -p $MONGODB_ROOT_PASSWORD --quiet --eval "db.restaurants.find()""

kubectl exec -ti my-release-mongodb-0 -n mongo-test -- bash

exit 
