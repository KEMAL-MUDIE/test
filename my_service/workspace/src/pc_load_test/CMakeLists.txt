cmake_minimum_required(VERSION 3.8)
project(pc_load_test)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
endif()
if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(ament_cmake_python REQUIRED)
find_package(rclcpp REQUIRED)
find_package(rclpy REQUIRED)
find_package(sensor_msgs REQUIRED)

add_executable(cpp_sub src/cpp_sub.cpp)
ament_target_dependencies(cpp_sub rclcpp sensor_msgs)
install(TARGETS cpp_sub DESTINATION lib/${PROJECT_NAME})

ament_python_install_package(${PROJECT_NAME})

install(PROGRAMS
  scripts/py_sub.py
  scripts/topic_test.py
  DESTINATION lib/${PROJECT_NAME}
)

install(DIRECTORY launch DESTINATION share/${PROJECT_NAME})

ament_package()
