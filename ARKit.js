//
//  index.js
//
//  Created by HippoAR on 7/9/17.
//  Copyright © 2017 HippoAR. All rights reserved.
//

import {
  StyleSheet,
  View,
  Text,
  NativeModules,
  requireNativeComponent,
} from 'react-native';
import { keyBy, mapValues, isBoolean } from 'lodash';
import PropTypes from 'prop-types';
import React, { Component } from 'react';

import {
  deprecated,
  detectionImages,
  planeDetection,
  position,
  transition,
} from './components/lib/propTypes';
import { pickColors, pickColorsFromFile } from './lib/pickColors';
import generateId from './components/lib/generateId';

const ARKitManager = NativeModules.ARKitManager;

const TRACKING_STATES = ['NOT_AVAILABLE', 'LIMITED', 'NORMAL'];

const TRACKING_REASONS = [
  'NONE',
  'INITIALIZING',
  'EXCESSIVE_MOTION',
  'INSUFFICIENT_FEATURES',
];
const TRACKING_STATES_COLOR = ['red', 'orange', 'green'];

class ARKit extends Component {
  state = {
    state: 0,
    reason: 0,
    floor: null,
  };

  componentDidMount() {
    ARKitManager.resume();
  }

  componentWillUnmount() {
    ARKitManager.pause();
  }

  getCallbackProps() {
    return mapValues(
      keyBy([
        'onTapOnPlaneUsingExtent',
        'onTapOnPlaneNoExtent',
        'onPlaneDetected',
        'onPlaneRemoved',
        'onPlaneUpdated',
        'onAnchorDetected',
        'onAnchorUpdated',
        'onAnchorRemoved',
        'onTrackingState',
        'onARKitError',
      ]),
      name => this.callback(name),
    );
  }

  render(AR = RCTARKit) {
    let state = null;
    if (this.props.debug) {
      state = (
        <View style={styles.statePanel}>
          <View
            style={[
              styles.stateIcon,
              { backgroundColor: TRACKING_STATES_COLOR[this.state.state] },
            ]}
          />
          <Text style={styles.stateText}>
            {TRACKING_REASONS[this.state.reason] || this.state.reason}
          </Text>
        </View>
      );
    }
    return (
      <View style={this.props.style}>
        <AR
          {...this.props}
          {...this.getCallbackProps()}
          // fallback to old prop type (Was boolean, now is enum)
          planeDetection={
            /* eslint no-nested-ternary: 0 */
            isBoolean(this.props.planeDetection)
              ? this.props.planeDetection
                ? ARKitManager.ARPlaneDetection.Horizontal
                : ARKitManager.ARPlaneDetection.None
              : this.props.planeDetection
          }
          onEvent={this._onEvent}
        />
        {state}
      </View>
    );
  }

  _onTrackingState = ({
    state = this.state.state,
    reason = this.state.reason,
  }) => {
    if (this.props.onTrackingState) {
      this.props.onTrackingState({
        state: TRACKING_STATES[state] || state,
        reason: TRACKING_REASONS[reason] || reason,
      });
    }
    // TODO: check if we can remove this
    if (this.props.debug) {
      this.setState({
        state,
        reason,
      });
    }
  };

  _onEvent = event => {
    let eventName = event.nativeEvent.event;
    if (!eventName) {
      return;
    }
    eventName = eventName.charAt(0).toUpperCase() + eventName.slice(1);
    const eventListener = this.props[`on${eventName}`];
    if (eventListener) {
      eventListener(event.nativeEvent);
    }
  };

  // handle deprecated alias
  _onPlaneUpdated = nativeEvent => {
    if (this.props.onPlaneUpdate) {
      this.props.onPlaneUpdate(nativeEvent);
    }
    if (this.props.onPlaneUpdated) {
      this.props.onPlaneUpdated(nativeEvent);
    }
  };

  callback(name) {
    return event => {
      if (this[`_${name}`]) {
        this[`_${name}`](event.nativeEvent);
        return;
      }
      if (!this.props[name]) {
        return;
      }
      this.props[name](event.nativeEvent);
    };
  }
}

const styles = StyleSheet.create({
  statePanel: {
    position: 'absolute',
    top: 30,
    left: 10,
    height: 20,
    borderRadius: 10,
    padding: 4,
    backgroundColor: 'black',
    flexDirection: 'row',
  },
  stateIcon: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 4,
  },
  stateText: {
    color: 'white',
    fontSize: 10,
    height: 12,
  },
});

// copy all ARKitManager properties to ARKit
Object.keys(ARKitManager).forEach(key => {
  ARKit[key] = ARKitManager[key];
});

const addDefaultsToSnapShotFunc = funcName => (
  { target = 'cameraRoll', format = 'png' } = {},
) => ARKitManager[funcName]({ target, format });

ARKit.snapshot = addDefaultsToSnapShotFunc('snapshot');
ARKit.snapshotCamera = addDefaultsToSnapShotFunc('snapshotCamera');

ARKit.exportModel = presetId => {
  const id = presetId || generateId();
  const property = { id };
  return ARKitManager.exportModel(property).then(result => ({ ...result, id }));
};

ARKit.pickColors = pickColors;
ARKit.pickColorsFromFile = pickColorsFromFile;
ARKit.propTypes = {
  debug: PropTypes.bool,
  planeDetection,
  origin: PropTypes.shape({
    position,
    transition,
  }),
  lightEstimationEnabled: PropTypes.bool,
  autoenablesDefaultLighting: PropTypes.bool,
  worldAlignment: PropTypes.number,
  detectionImages,
  onARKitError: PropTypes.func,

  onFeaturesDetected: PropTypes.func,
  // onLightEstimation is called rapidly, better poll with
  // ARKit.getCurrentLightEstimation()
  onLightEstimation: PropTypes.func,

  onPlaneDetected: PropTypes.func,
  onPlaneRemoved: PropTypes.func,
  onPlaneUpdated: PropTypes.func,
  onPlaneUpdate: deprecated(PropTypes.func, 'Use `onPlaneUpdated` instead'),

  onAnchorDetected: PropTypes.func,
  onAnchorRemoved: PropTypes.func,
  onAnchorUpdated: PropTypes.func,

  onTrackingState: PropTypes.func,
  onTapOnPlaneUsingExtent: PropTypes.func,
  onTapOnPlaneNoExtent: PropTypes.func,
  onEvent: PropTypes.func,
  isMounted: PropTypes.func,
  isInitialized: PropTypes.func,
};

const RCTARKit = requireNativeComponent('RCTARKit', ARKit);

export default ARKit;
