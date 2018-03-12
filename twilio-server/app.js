/**
 * Copyright 2016, Google, Inc.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// [START app]
'use strict';

const format = require('util').format;
const express = require('express');
const bodyParser = require('body-parser').urlencoded({
  extended: false
});

var shell = require('shelljs');

const request = require('request');
const app = express();

// [START config]
const TWILIO_NUMBER = process.env.TWILIO_NUMBER;
if (!TWILIO_NUMBER) {
  console.log('Please configure environment variables as described in README.md');
  process.exit(1);
}

const twilio = require('twilio')(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

const TwimlResponse = require('twilio').TwimlResponse;
// [END config]

// [START receive_call]
app.post('/call/receive', (req, res) => {
  const resp = new TwimlResponse();
  resp.say('Hello from Google App Engine.');

  res.status(200)
    .contentType('text/xml')
    .send(resp.toString());
});
// [END receive_call]

// [START send_sms]
app.get('/sms/send', (req, res, next) => {
  const to = req.query.to;
  if (!to) {
    res.status(400).send('Please provide an number in the "to" query string parameter.');
    return;
  }

  twilio.sendMessage({
    to: to,
    from: TWILIO_NUMBER,
    body: 'Hello from Google App Engine'
  }, (err) => {
    if (err) {
      next(err);
      return;
    }
    res.status(200).send('Message sent.');
  });
});
// [END send_sms]

// [START receive_sms]
app.post('/sms/receive', bodyParser, (req, res) => {
  const sender = req.body.From;
  var body = req.body.Body;

  console.log("this is the command: ");
  console.log(body);
  body = body.toLowerCase();


  twilio.sendMessage({
    to: sender,
    from: TWILIO_NUMBER,
    body: 'Got your text, please wait for processing...'
  }, (err) => {
    if (err) {
      next(err);
      return;
    }
  });

  if (body.startsWith("t8s")) {
  
    var t8s = '<path to t8s.sh>'

    shell.exec(t8s + body.substring(3,), function(code, stdout, stderr) {
        console.log(code);
        console.log(stderr);

        console.log("************");
        console.log(stdout);
        console.log("************");

        if (code !== 0) {
          shell.echo('Error: failed rip');
          shell.exit(1);
        } else {
          var data = stdout;
        }


        console.log("+++++++");
        console.log(data);
        console.log("+++++++");
        console.log(body.substring(9, 17));
        if (body.substring(9, 15) == "update" || body.substring(9,17) == "rollback") {
          console.log('in here');
          var heydata=data.substring(data.length-83, data.length-1);
        } else {
          var heydata=data;
        }
          
          if (body.substring(9,15) == "update") {
            heydata = "Your deployment has been updated. Do you want to test it? (say yes or test)";
          } else if (body.substring(9,17) == "rollback") {
            heydata = "Successfully rolled back. Do you want to test? (say yes or test)";
          }
        
          twilio.sendMessage({
            to: sender,
            from: TWILIO_NUMBER,
            body: heydata
          }, (err) => {
            if (err) {
              next(err);
              return;
            }
          });

    });

    res.status(200)
          .contentType('text/xml')
          .send("Done");
 
  } else if (body.startsWith("k")) {

    var k = '/usr/local/bin/kubectl'
    var command = shell.exec(k + body.substring(1,));
    console.log("************");
    console.log(command.stdout);
    console.log("************");

    if (command.code !== 0) {
      shell.echo('Error: failed rip');
      shell.exit(1);
    } else {
      var data = command.stdout;
    }

    const resp = new TwimlResponse();
    resp.message(format('Here is your info:\n %s', data));

    res.status(200)
      .contentType('text/xml')
      .send(resp.toString());


  } else if (  body.startsWith("yes") || body.startsWith("test") ) {

      var k = '/usr/local/bin/kubectl'
      shell.exec("kubectl get service -o json | jq -r '.items[] | select(.spec.type==\"LoadBalancer\") | .status.loadBalancer.ingress[].ip'", function(code, stdout, stderr) {
          shell.exec("curl " + stdout, function(code, stdout, stderr) {
              console.log(stdout);


              console.log("************");
              console.log(stdout);
              console.log("************");

              if (code !== 0) {
                shell.echo('Error: failed rip');
                shell.exit(1);
              } else {
                var data = stdout;
              }

              const resp = new TwimlResponse();
              resp.message(format('Here is your info:\n %s', data));



              res.status(200)
                .contentType('text/xml')
                .send(resp.toString());

              });



          });
      




   
  } else {


    const resp = new TwimlResponse();
        resp.message(format('You must start your command with t8s.'));

        res.status(200)
          .contentType('text/xml')
          .send(resp.toString());
  }

});
// [END receive_sms]

// Start the server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`App listening on port ${PORT}`);
  console.log('Press Ctrl+C to quit.');
});
// [END app]
