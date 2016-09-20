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

#include "susi/MQTTClient.h"
#include "susi/BaseApp.h"

class MQTTApp : public Susi::BaseApp {
protected:
  std::shared_ptr<Susi::MQTTClient> _mqttComponent;

public:
  MQTTApp(int argc, char **argv) : Susi::BaseApp{argc, argv} {}
  virtual ~MQTTApp() {}
  virtual void start() override {
    _mqttComponent.reset(new Susi::MQTTClient{*_susi, _config["component"]});
  }
};

int main(int argc, char *argv[]) {
  try {
    MQTTApp app{argc, argv};
    app.start();
    app.join();
  } catch (const std::exception &e) {
    std::cout << e.what() << std::endl;
    return 1;
  }
  return 0;
}
