// Code generated by mockery v2.53.0. DO NOT EDIT.

package mocks

import mock "github.com/stretchr/testify/mock"

// PipelineParamUnmarshaler is an autogenerated mock type for the PipelineParamUnmarshaler type
type PipelineParamUnmarshaler struct {
	mock.Mock
}

type PipelineParamUnmarshaler_Expecter struct {
	mock *mock.Mock
}

func (_m *PipelineParamUnmarshaler) EXPECT() *PipelineParamUnmarshaler_Expecter {
	return &PipelineParamUnmarshaler_Expecter{mock: &_m.Mock}
}

// UnmarshalPipelineParam provides a mock function with given fields: val
func (_m *PipelineParamUnmarshaler) UnmarshalPipelineParam(val interface{}) error {
	ret := _m.Called(val)

	if len(ret) == 0 {
		panic("no return value specified for UnmarshalPipelineParam")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func(interface{}) error); ok {
		r0 = rf(val)
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// PipelineParamUnmarshaler_UnmarshalPipelineParam_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'UnmarshalPipelineParam'
type PipelineParamUnmarshaler_UnmarshalPipelineParam_Call struct {
	*mock.Call
}

// UnmarshalPipelineParam is a helper method to define mock.On call
//   - val interface{}
func (_e *PipelineParamUnmarshaler_Expecter) UnmarshalPipelineParam(val interface{}) *PipelineParamUnmarshaler_UnmarshalPipelineParam_Call {
	return &PipelineParamUnmarshaler_UnmarshalPipelineParam_Call{Call: _e.mock.On("UnmarshalPipelineParam", val)}
}

func (_c *PipelineParamUnmarshaler_UnmarshalPipelineParam_Call) Run(run func(val interface{})) *PipelineParamUnmarshaler_UnmarshalPipelineParam_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(interface{}))
	})
	return _c
}

func (_c *PipelineParamUnmarshaler_UnmarshalPipelineParam_Call) Return(_a0 error) *PipelineParamUnmarshaler_UnmarshalPipelineParam_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *PipelineParamUnmarshaler_UnmarshalPipelineParam_Call) RunAndReturn(run func(interface{}) error) *PipelineParamUnmarshaler_UnmarshalPipelineParam_Call {
	_c.Call.Return(run)
	return _c
}

// NewPipelineParamUnmarshaler creates a new instance of PipelineParamUnmarshaler. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewPipelineParamUnmarshaler(t interface {
	mock.TestingT
	Cleanup(func())
}) *PipelineParamUnmarshaler {
	mock := &PipelineParamUnmarshaler{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}
