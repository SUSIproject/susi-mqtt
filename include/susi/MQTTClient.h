/*
 * Copyright (c) 2016, Tino Rusch
 *
 * This file is released under the terms of the MIT license. You can find the
 * complete text in the attached LICENSE file or online at:
 *
 * http://www.opensource.org/licenses/mit-license.php
 *
 * @author: Tino Rusch (tino.rusch@webvariants.de)
 */

#include "susi/SusiClient.h"
#include <mosquittopp.h>

namespace Susi {
class MQTTClient : public mosqpp::mosquittopp {

public:
  MQTTClient(Susi::SusiClient &susi, BSON::Value &config);
  void join();

protected:
  Susi::SusiClient &susi_;
  std::thread runloop_;
  std::vector<std::string> subscriptions_;

  void subscribe(const std::string &topic);
  void forward(const std::string &topic);

  void on_connect(int rc);
  void on_message(const struct mosquitto_message *message);
  void on_subscribe(int mid, int qos_count, const int *granted_qos);
};
}
