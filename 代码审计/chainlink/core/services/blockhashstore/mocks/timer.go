// Code generated by mockery v2.53.0. DO NOT EDIT.

package mocks

import (
	time "time"

	mock "github.com/stretchr/testify/mock"
)

// Timer is an autogenerated mock type for the Timer type
type Timer struct {
	mock.Mock
}

type Timer_Expecter struct {
	mock *mock.Mock
}

func (_m *Timer) EXPECT() *Timer_Expecter {
	return &Timer_Expecter{mock: &_m.Mock}
}

// After provides a mock function with given fields: d
func (_m *Timer) After(d time.Duration) <-chan time.Time {
	ret := _m.Called(d)

	if len(ret) == 0 {
		panic("no return value specified for After")
	}

	var r0 <-chan time.Time
	if rf, ok := ret.Get(0).(func(time.Duration) <-chan time.Time); ok {
		r0 = rf(d)
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(<-chan time.Time)
		}
	}

	return r0
}

// Timer_After_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'After'
type Timer_After_Call struct {
	*mock.Call
}

// After is a helper method to define mock.On call
//   - d time.Duration
func (_e *Timer_Expecter) After(d interface{}) *Timer_After_Call {
	return &Timer_After_Call{Call: _e.mock.On("After", d)}
}

func (_c *Timer_After_Call) Run(run func(d time.Duration)) *Timer_After_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(time.Duration))
	})
	return _c
}

func (_c *Timer_After_Call) Return(_a0 <-chan time.Time) *Timer_After_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Timer_After_Call) RunAndReturn(run func(time.Duration) <-chan time.Time) *Timer_After_Call {
	_c.Call.Return(run)
	return _c
}

// NewTimer creates a new instance of Timer. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewTimer(t interface {
	mock.TestingT
	Cleanup(func())
}) *Timer {
	mock := &Timer{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}
