var Connection = require('tedious').Connection;
var Request = require('tedious').Request
var TYPES = require('tedious').TYPES;

const executeSQL = (context, procedureName, customerId = null) => {
    var result = "";

    // Create Connection object
    const connection = new Connection({
        server: process.env["db_server"],
        authentication: {
            type: 'default',
            options: {
                userName: process.env["db_user"],
                password: process.env["db_password"],
            }
        },
        options: {
            database: process.env["db_database"],
            encrypt: true
        }
    });

    // Create the command to be executed
    const request = new Request(procedureName, (err) => {
        if (err) {
            context.log.error(err);            
            context.res.status = 500;
            context.res.body = "Error executing T-SQL command";
        } else {
            context.res = {
                body: result,
                headers: {
                    'Content-Type': 'application/json'
                }
            }   
        }
        context.done();
    });
    
    // Add parameter if customerId is provided
    if (customerId !== null) {
        request.addParameter('CustomerID', TYPES.Int, customerId);
    }

    // Handle 'connect' event
    connection.on('connect', err => {
        if (err) {
            context.log.error(err);              
            context.res.status = 500;
            context.res.body = "Error connecting to Azure SQL query";
            context.done();
        }
        else {
            // Connection succeeded so execute T-SQL stored procedure
            connection.callProcedure(request);
        }
    });

    // Handle result set sent back from Azure SQL
    request.on('row', columns => {
        columns.forEach(column => {
            result += column.value;                
        });
    });

    // Connect
    connection.connect();
}

module.exports = function (context, req) {    
    const method = req.method.toLowerCase();
    
    // このハンズオンでは GET メソッドのみをサポート
    if (method !== "get") {
        context.res = {
            status: 405,
            body: "Method not allowed. This hands-on example only supports GET requests."
        };
        context.done();
        return;
    }

    // パラメータに ID が指定されている場合
    if (req.params.id) {
        const customerId = parseInt(req.params.id);
        if (isNaN(customerId)) {
            context.res = {
                status: 400,
                body: "Invalid customer ID"
            };
            context.done();
            return;
        }
        
        // 特定の顧客を取得
        executeSQL(context, 'dbo.GetCustomerById', customerId);
    } else {
        // すべての顧客を取得
        executeSQL(context, 'dbo.GetAllCustomers');
    }
}