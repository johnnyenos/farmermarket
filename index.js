const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const dynamoDB = new AWS.DynamoDB.DocumentClient();

const BUCKET_NAME = process.env.BUCKET_NAME;
const TABLE_NAME = process.env.TABLE_NAME;

exports.handler = async (event) => {
    const httpMethod = event.httpMethod;
    const path = event.path;
    let response;

    try {
        if (httpMethod === 'GET' && path === '/products') {
            response = await getProducts();
        } else if (httpMethod === 'POST' && path === '/products') {
            const body = JSON.parse(event.body);
            response = await addProduct(body);
        } else if (httpMethod === 'DELETE' && path.startsWith('/products/')) {
            const productId = path.split('/')[2];
            response = await deleteProduct(productId);
        } else {
            response = {
                statusCode: 405,
                body: JSON.stringify({ message: "Method Not Allowed" }),
            };
        }
    } catch (error) {
        console.error(error);
        response = {
            statusCode: 500,
            body: JSON.stringify({ message: "Internal Server Error" }),
        };
    }

    return {
        statusCode: response.statusCode,
        body: response.body,
        headers: {
            'Content-Type': 'application/json',
        },
    };
};

async function getProducts() {
    const params = {
        TableName: TABLE_NAME,
    };

    const data = await dynamoDB.scan(params).promise();
    return {
        statusCode: 200,
        body: JSON.stringify(data.Items),
    };
}

async function addProduct(product) {
    const productId = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    const s3Params = {
        Bucket: BUCKET_NAME,
        Key: `products/${productId}/${product.imageName}`,
        Body: Buffer.from(product.imageBase64, 'base64'),
        ContentType: product.imageContentType,
    };

    const s3Response = await s3.upload(s3Params).promise();

    const dynamoParams = {
        TableName: TABLE_NAME,
        Item: {
            productId: productId,
            productName: product.name,
            productDescription: product.description,
            productPrice: product.price,
            productImageUrl: s3Response.Location,
        },
    };

    await dynamoDB.put(dynamoParams).promise();

    return {
        statusCode: 201,
        body: JSON.stringify({ message: "Product added successfully", productId: productId }),
    };
}

async function deleteProduct(productId) {
    const getParams = {
        TableName: TABLE_NAME,
        Key: { productId: productId },
    };

    const data = await dynamoDB.get(getParams).promise();

    if (!data.Item) {
        return {
            statusCode: 404,
            body: JSON.stringify({ message: "Product not found" }),
        };
    }

    const deleteS3Params = {
        Bucket: BUCKET_NAME,
        Key: `products/${productId}/${data.Item.productImageName}`,
    };

    await s3.deleteObject(deleteS3Params).promise();

    const deleteDynamoParams = {
        TableName: TABLE_NAME,
        Key: { productId: productId },
    };

    await dynamoDB.delete(deleteDynamoParams).promise();

    return {
        statusCode: 200,
        body: JSON.stringify({ message: "Product deleted successfully" }),
    };
}
