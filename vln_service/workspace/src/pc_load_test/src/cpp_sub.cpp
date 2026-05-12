// One C++ PointCloud2 subscriber instance for the load test.
//
// Usage: cpp_sub <name_suffix> <mode 0|1|2> <topic>
//   mode 0: Hz + Bandwidth + Delay
//   mode 1: Hz
//   mode 2: Hz + Delay
//
// Mirrors the python StatsSubscriber so output lines are directly comparable.

#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <mutex>
#include <string>

#include "rclcpp/rclcpp.hpp"
#include "sensor_msgs/msg/point_cloud2.hpp"

namespace {
constexpr std::size_t kHeaderOverheadBytes = 100;

double monotonic_now_s()
{
  return std::chrono::duration<double>(
           std::chrono::steady_clock::now().time_since_epoch())
    .count();
}
}  // namespace

class StatsSubscriber : public rclcpp::Node
{
public:
  StatsSubscriber(const std::string & node_name, const std::string & topic, int mode)
  : rclcpp::Node(node_name), topic_(topic), mode_(mode), last_print_(monotonic_now_s())
  {
    // Match /ouster/points publisher (RELIABLE + TRANSIENT_LOCAL).
    // VOLATILE on the sub avoids history replay; QoS-compatible with TRANSIENT_LOCAL pub.
    auto qos = rclcpp::QoS(rclcpp::KeepLast(10))
                 .reliability(rclcpp::ReliabilityPolicy::Reliable)
                 .durability(rclcpp::DurabilityPolicy::Volatile);
    sub_ = create_subscription<sensor_msgs::msg::PointCloud2>(
      topic, qos,
      [this](sensor_msgs::msg::PointCloud2::ConstSharedPtr msg) { this->cb(msg); });
    timer_ = create_wall_timer(
      std::chrono::seconds(1), [this]() { this->report(); });
  }

private:
  void cb(sensor_msgs::msg::PointCloud2::ConstSharedPtr msg)
  {
    const std::size_t size = msg->data.size() + kHeaderOverheadBytes;
    const double stamp_s =
      static_cast<double>(msg->header.stamp.sec) +
      static_cast<double>(msg->header.stamp.nanosec) * 1e-9;
    const double now_s = static_cast<double>(now().nanoseconds()) * 1e-9;
    const double delay = now_s - stamp_s;

    std::lock_guard<std::mutex> lock(mu_);
    count_ += 1;
    bytes_ += size;
    if (stamp_s > 0.0) {
      delay_sum_ += delay;
      delay_n_ += 1;
    }
  }

  void report()
  {
    std::uint64_t count;
    std::uint64_t bytes;
    double delay_sum;
    int delay_n;
    double dt;
    {
      std::lock_guard<std::mutex> lock(mu_);
      const double now_m = monotonic_now_s();
      dt = now_m - last_print_;
      if (dt <= 0.0) {
        return;
      }
      count = count_;
      bytes = bytes_;
      delay_sum = delay_sum_;
      delay_n = delay_n_;
      count_ = 0;
      bytes_ = 0;
      delay_sum_ = 0.0;
      delay_n_ = 0;
      last_print_ = now_m;
    }

    const double hz = static_cast<double>(count) / dt;
    const double bw_mibps =
      (static_cast<double>(bytes) / dt) / (1024.0 * 1024.0);
    const double delay_ms =
      delay_n > 0 ? (delay_sum / delay_n) * 1000.0 : std::nan("");
    const std::string name = get_name();

    if (mode_ == 0) {
      std::printf(
        "[%-22s] Hz=%6.2f  BW=%7.2f MiB/s  Delay=%7.1f ms  topic=%s\n",
        name.c_str(), hz, bw_mibps, delay_ms, topic_.c_str());
    } else if (mode_ == 1) {
      std::printf(
        "[%-22s] Hz=%6.2f  topic=%s\n", name.c_str(), hz, topic_.c_str());
    } else if (mode_ == 2) {
      std::printf(
        "[%-22s] Hz=%6.2f  Delay=%7.1f ms  topic=%s\n",
        name.c_str(), hz, delay_ms, topic_.c_str());
    } else {
      std::printf(
        "[%-22s] (unknown mode %d)\n", name.c_str(), mode_);
    }
    std::fflush(stdout);
  }

  std::string topic_;
  int mode_;
  rclcpp::Subscription<sensor_msgs::msg::PointCloud2>::SharedPtr sub_;
  rclcpp::TimerBase::SharedPtr timer_;
  std::mutex mu_;
  std::uint64_t count_ = 0;
  std::uint64_t bytes_ = 0;
  double delay_sum_ = 0.0;
  int delay_n_ = 0;
  double last_print_;
};

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  if (argc < 4) {
    std::fprintf(
      stderr, "usage: %s <name_suffix> <mode 0|1|2> <topic>\n", argv[0]);
    rclcpp::shutdown();
    return 2;
  }
  const std::string suffix = argv[1];
  const int mode = std::atoi(argv[2]);
  const std::string topic = argv[3];

  auto node = std::make_shared<StatsSubscriber>(
    "cpp_sub_" + suffix, topic, mode);
  rclcpp::spin(node);
  rclcpp::shutdown();
  return 0;
}
